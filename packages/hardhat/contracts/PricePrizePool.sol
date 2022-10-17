pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PricePrizePool is Ownable, AccessControl {

  using SafeMath for uint256;

  event Deposited(uint32 indexed roundId, address indexed user, uint32 indexed guess, uint256 amount);

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

  // The final price of ETH of this round
  uint32 public ethPrice;

  // The winning guess, which is the closest price to ethPrice
  uint32 public winningGuess;

  // The id of the current round
  uint32 public roundId;

  // The duration when people can bet
  uint32 public betPeriodSeconds;

  // The start time of this round
  uint64 public roundStartedAt;

  // The timestamp when ethPrice is set
  uint64 public priceSetAt;

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
      ethPrice = uint32(uint256(price) / 10**(decimals-2));

      priceSetAt = _currentTime();
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


  }

  /// @notice Start a new round
  function nextRound() external onlyManagerOrOwner {
      require(_canClaim(), "This round is not finished yet");
      roundId++;
      roundStartedAt = _currentTime();
      ethPrice = 0;
      winningGuess = 0;
      roundTotal = 0;
      payable(owner()).transfer(address(this).balance);
  }

  /// @notice Claim the prize! 5% fee will be charged.
  function claim() external returns (uint256) {
    require(_canClaim(), "You cannot claim yet");

    uint256 myDeposit = bets[roundId][msg.sender][winningGuess];
    if (myDeposit > 0) {
      uint256 totalDeposit = guessTotalDeposit[roundId][winningGuess];
      uint256 payout = roundTotal.mul(myDeposit).div(totalDeposit).mul(19).div(20);
      payable(msg.sender).transfer(payout);
      return payout;
    }
    return 0;
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
      return _isGuessTimeOver() && ethPrice > 0 && winningGuess > 0;
  }
}
