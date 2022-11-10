pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PricePrizePool is Ownable, AccessControl {

  using SafeMath for uint256;

  struct Round {
    uint32 roundId;
    uint32 ethPrice;
    uint256 roundTotal;
    uint256 notClaimed;
  }

  event Deposited(uint32 indexed roundId, address indexed user, uint32 indexed guess, uint256 amount);

  /// @notice Max history rounds that will be stored
  uint8 public constant MAX_CARDINALITY = 7;

  /// @notice Rounds ring buffer array.
  Round[MAX_CARDINALITY] public roundRingBuffer;

  // The Automation Registry address will be assigned this role
  // It's updatable by the owner of this contract
  // Only address with this role can set the final winning guess of this round
  bytes32 public constant MANAGE_ROLE = keccak256("MANAGE_ROLE");

  modifier onlyManagerOrOwner {
      require(msg.sender == owner() || hasRole(MANAGE_ROLE, msg.sender));
      _;
  }

  // Store all the bets
  // Structure is bets[roundId][guess][user's address] => how much user depositted
  mapping(uint32 => mapping(address => mapping(uint32 => uint256))) public bets;

  // Store the total amount of deposits of each guess
  mapping(uint32 => mapping(uint32 => uint256)) public guessTotalDeposit;

  // Store the total deposit of this round
  uint256 public roundTotal;

  // Store the unclaimed prize
  uint256 public toCollect;

  // ETH/USD price feed from Chainlink
  AggregatorV3Interface internal priceFeed;

  // The id of the current round
  uint32 public roundId;

  // The duration when people can bet
  uint32 public betPeriodSeconds;

  // The time between bet ending time and price set
  uint32 public priceSetSeconds;

  // The start time of this round
  uint64 public roundStartedAt;

  /* ============ Constructor ============ */

  /// @notice Deploy the Price Prize Pool
  /// @param _betPeriodSeconds The duration when people can bet
  /// @param _priceSetSeconds The time between bet ending time and price set
  constructor(uint32 _betPeriodSeconds, uint32 _priceSetSeconds) {
    priceFeed = AggregatorV3Interface(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e);
    betPeriodSeconds = _betPeriodSeconds;
    priceSetSeconds = _priceSetSeconds;
    roundStartedAt = _currentTime();
    roundId = 1;
  }

  /// @notice Deposit to make a guess
  /// @param _guess The price the user bet
  function deposit(uint32 _guess) external payable {

    require(msg.value >= 10 ** 16, "Minimum deposit is 0.01!");
    require(!_isGuessTimeOver(), "Guessing time is over!");

    bets[roundId][msg.sender][_guess] += msg.value;
    guessTotalDeposit[roundId][_guess] += msg.value;
    roundTotal += msg.value;

    emit Deposited(roundId, msg.sender, _guess, msg.value);
  }

  /// @notice Update the manage role
  /// @param _oldManager the previous account who has the manage role
  /// @param _newManager the account who will be assigned the manage role
  function updateManageRole(address _oldManager, address _newManager) external onlyOwner {
    if (hasRole(MANAGE_ROLE, _oldManager)) {
      _revokeRole(MANAGE_ROLE, _oldManager);
    }
    _setupRole(MANAGE_ROLE, _newManager);
  }

  function changeBetSeconds(uint32 betSeconds) external onlyOwner {
    betPeriodSeconds = betSeconds;
  }

  function changePriceSetSeconds(uint32 priceSeconds) external onlyOwner {
    priceSetSeconds = priceSeconds;
  }

  function collectBalance() external onlyOwner {
    if (toCollect > 0) {
      payable(owner()).transfer(toCollect);
      toCollect = 0;
    }
  }

  /// @notice Set the ethPrice
  function setFinalPrice() external onlyManagerOrOwner {

      (
          /*uint80 roundID*/,
          int price,
          /*uint startedAt*/,
          /*uint timeStamp*/,
          /*uint80 answeredInRound*/
      ) = priceFeed.latestRoundData();
      uint8 decimals = priceFeed.decimals();
      uint16 ethPrice = uint16(uint256(price) / 10**decimals);
      uint32 index = (roundId - 1) % MAX_CARDINALITY;
      Round memory toRemove = roundRingBuffer[index];
      if (toRemove.notClaimed > 0) {
        toCollect += toRemove.notClaimed;
      }

      uint256 nc = roundTotal;
      uint256 rt = roundTotal;
      uint256 totalDeposit = guessTotalDeposit[roundId][ethPrice];
      if (totalDeposit > 0) {
        roundTotal = 0;
      } else {
        nc = 0;
      }
      roundRingBuffer[index] = Round({
        ethPrice: ethPrice,
        roundId: roundId,
        roundTotal: rt,
        notClaimed: nc
      });

      roundId++;
      roundStartedAt = _currentTime();
  }

  function myWinnings(address player) public view returns (uint256[MAX_CARDINALITY] memory) {
    uint256[MAX_CARDINALITY] memory res;
    for (uint8 i=0; i<MAX_CARDINALITY; i++) {
      Round memory round = roundRingBuffer[i];
      res[i] = bets[round.roundId][player][round.ethPrice];
      if (res[i] > 0) {
        uint256 totalDeposit = guessTotalDeposit[round.roundId][round.ethPrice];
        res[i] = round.roundTotal.mul(res[i]).div(totalDeposit).mul(19).div(20);    
      }
    }
    return res;
  }

  /// @notice Claim the prize! 5% fee will be charged.
  function claim(uint32 _roundId) external returns (uint256) {

    require(_canClaim(), "Next round will start in less than 1 minute, cannot claim now!");

    uint32 index = (_roundId - 1) % MAX_CARDINALITY;
    Round memory round = roundRingBuffer[index];
    require(round.roundId == _roundId && _roundId != 0, "roundId is not valid");

    uint256 myDeposit = bets[round.roundId][msg.sender][round.ethPrice];
    require(myDeposit > 0, "Nothing to claim");

    uint256 totalDeposit = guessTotalDeposit[round.roundId][round.ethPrice];
    uint256 payout = round.roundTotal.mul(myDeposit).div(totalDeposit).mul(19).div(20);

    bets[round.roundId][msg.sender][round.ethPrice] = 0;
    round.notClaimed -= payout;
    roundRingBuffer[index] = round;
    payable(msg.sender).transfer(payout);

    return payout;
  }

  function generalInfo() external view returns (uint32, uint64, uint64, uint256) {
    uint64 betEndingTime = roundStartedAt + betPeriodSeconds;
    return (roundId, betEndingTime, betEndingTime + priceSetSeconds, roundTotal);
  }

  /* ============ Internal Functions ============ */

  function _currentTime() internal view virtual returns (uint64) {
      return uint64(block.timestamp);
  }

  function _isGuessTimeOver() internal view virtual returns (bool) {
    uint64 currentTime = _currentTime();
    return currentTime > roundStartedAt + betPeriodSeconds;
  }

  function _canClaim() internal view virtual returns (bool) {
    uint64 priceSetTime = roundStartedAt + betPeriodSeconds + priceSetSeconds;
    uint64 currentTime = _currentTime();
    uint64 diff = currentTime > priceSetTime ? (currentTime - priceSetTime) : (priceSetTime - currentTime);
    return diff >= 60;
  }
}
