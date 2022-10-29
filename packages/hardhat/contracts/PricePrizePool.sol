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
    uint256 roundTotal;
    uint32 ethPrice;
    uint64 priceSetAt;
    uint32 winningGuess;
    uint256 notClaimed;
  }

  event Deposited(uint32 indexed roundId, address indexed user, uint32 indexed guess, uint256 amount);

  /// @notice Max history rounds that will be stored
  uint8 public constant MAX_CARDINALITY = 7;

  /// @notice Rounds ring buffer array.
  Round[MAX_CARDINALITY] private roundRingBuffer;

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

  // ETH/USD price feed from Chainlink
  AggregatorV3Interface internal priceFeed;

  // The id of the current round
  uint32 public roundId;

  // The duration when people can bet
  uint32 public betPeriodSeconds;

  // The start time of this round
  uint64 public roundStartedAt;

  /* ============ Constructor ============ */

  /// @notice Deploy the Price Prize Pool
  /// @param _betPeriodSeconds The duration when people can bet
  constructor(uint32 _betPeriodSeconds) {
    priceFeed = AggregatorV3Interface(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e);
    betPeriodSeconds = _betPeriodSeconds;
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

  /// @notice Set the ethPrice
  function setFinalPrice() external onlyManagerOrOwner {
      require(_isGuessTimeOver(), "Guess time is not over yet!");

      (
          /*uint80 roundID*/,
          int price,
          /*uint startedAt*/,
          /*uint timeStamp*/,
          /*uint80 answeredInRound*/
      ) = priceFeed.latestRoundData();
      uint8 decimals = priceFeed.decimals();
      uint32 ethPrice = uint32(uint256(price) / 10**(decimals-2));
      uint64 priceSetAt = _currentTime();
      uint32 winningGuess = ethPrice;

      if (guessTotalDeposit[roundId][ethPrice] > 0) {
        winningGuess = ethPrice;
      } else {
        uint32 closestGuess = ethPrice;
        uint32 i = 1;
        while (i < 10000) {
          uint32 guessPriceUp = ethPrice + i;
          uint32 guessPriceDown = ethPrice - i;
          uint256 depositUp = guessTotalDeposit[roundId][guessPriceUp];
          uint256 depositDown = guessTotalDeposit[roundId][guessPriceDown];
          if (depositUp > 0 || depositDown > 0) {
            if (depositUp > 0 && depositDown > 0) {
              if (depositUp > depositDown) {
                closestGuess = guessPriceUp;
              } else {
                closestGuess = guessPriceDown;
              }
            } else if (depositUp > 0) {
              closestGuess = guessPriceUp;
            } else {
              closestGuess = guessPriceDown;
            }
            break;
          }
          i += 1;
        }
        winningGuess = closestGuess;
      }

      uint32 index = (roundId - 1) % MAX_CARDINALITY;
      Round memory toRemove = roundRingBuffer[index];
      if (toRemove.notClaimed > 0) {
        payable(owner()).transfer(toRemove.notClaimed);
      }
      
      roundRingBuffer[index] = Round({
        ethPrice: ethPrice,
        winningGuess: winningGuess,
        priceSetAt: priceSetAt,
        roundId: roundId,
        roundTotal: roundTotal,
        notClaimed: roundTotal
      });

      roundId++;
      roundStartedAt = _currentTime();
      roundTotal = 0;
      
  }

  function myWinnings(address player) public view returns (uint256[MAX_CARDINALITY] memory) {
    uint256[MAX_CARDINALITY] memory res;
    for (uint8 i=0; i<MAX_CARDINALITY; i++) {
      Round memory round = roundRingBuffer[i];
      if (round.roundTotal > 0 && round.winningGuess > 0) {
        uint256 myDeposit = bets[round.roundId][player][round.winningGuess];
        if (myDeposit > 0) {
          uint256 totalDeposit = guessTotalDeposit[round.roundId][round.winningGuess];
          uint256 payout = round.roundTotal.mul(myDeposit).div(totalDeposit).mul(19).div(20);
          res[i] = payout;
        }
      }
    }
    return res;
  }

  /// @notice Claim the prize! 5% fee will be charged.
  function claim() external returns (uint256) {
    uint256[MAX_CARDINALITY] memory myWinning = myWinnings(msg.sender);
    uint256 payout = 0;
    for (uint8 i=0; i<MAX_CARDINALITY; i++) {
      uint256 win = myWinning[i];
      if (win > 0) {
        Round memory round = roundRingBuffer[i];
        round.notClaimed -= win;
        roundRingBuffer[i] = round;
        payout += win;
      }
    }
    require(payout > 0, "Nothing to claim");
    payable(msg.sender).transfer(payout);
    return payout;
  }

  function generalInfo() external view returns (uint32, uint32, uint64, uint256) {
    return (roundId, betPeriodSeconds, roundStartedAt, roundTotal);
  }

  function priceInfo() external view returns (uint32, uint64, uint32) {
    if (roundId == 1) {
      return (0, 0, 0);
    }
    uint32 index = (roundId-2) % MAX_CARDINALITY;
    Round memory lastRound = roundRingBuffer[index];
    return (lastRound.ethPrice, lastRound.priceSetAt, lastRound.winningGuess);
  }

  /* ============ Internal Functions ============ */

  function _currentTime() internal view virtual returns (uint64) {
      return uint64(block.timestamp);
  }

  function _isGuessTimeOver() internal view virtual returns (bool) {
    uint64 currentTime = _currentTime();
    return currentTime > roundStartedAt + betPeriodSeconds;
  }
}
