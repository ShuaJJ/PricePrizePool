pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PricePrizePool is Ownable, AccessControl {

  event Deposited(address indexed user, int indexed guess, uint256 amount);

  // The Automation Registry address will be assigned this role
  // It's updatable by the owner of this contract
  // Only address with this role can set the final winning guess of this round
  bytes32 public constant MANAGE_ROLE = keccak256("MANAGE_ROLE");

  // Store all the bets made by users
  // Structure is bets[roundId][user's address][user's guess] => how much user depositted
  mapping(uint32 => mapping(address => mapping(int => uint256))) public bets;

  // Array of all the guesses users made
  // Will be used to determine the winning guess
  int[] guesses;

  // ETH/USD price feed from Chainlink
  AggregatorV3Interface internal priceFeed;

  // The final price of ETH of this round
  int ethPrice;

  // The winning guess, which is the closest price to ethPrice
  int winningGuess;

  // The id of the current round
  uint32 roundId;

  // The duration when people can bet
  uint32 internal betPeriodSeconds;

  // The start time of this round
  uint64 internal roundStartedAt;

  // The timestamp when ethPrice is set
  uint64 priceSetAt;

  /* ============ Constructor ============ */

  /// @notice Deploy the Price Prize Pool
  /// @param _betPeriodSeconds The duration when people can bet
  constructor(uint32 _betPeriodSeconds) {
    priceFeed = AggregatorV3Interface(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e);
    betPeriodSeconds = _betPeriodSeconds;
    roundStartedAt = _currentTime();
    roundId = 1;

    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  /// @notice Deposit to make a guess
  /// @param _guess The duration when people can bet
  function deposit(int _guess) external payable {

    require(msg.value >= 10 ** 16, "Minimum deposit is 0.01!");
    require(!_isGuessTimeOver(), "Guessing time is over!");

    bets[roundId][msg.sender][_guess] += msg.value;
    guesses.push(_guess);

    emit Deposited(msg.sender, _guess, msg.value);
  }

  /// @notice Update the manage role
  /// @param _oldManager the previous account who has the manage role
  /// @param _newManager the account who will be assigned the manage role
  function updateManageRole(address _oldManager, address _newManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (hasRole(MANAGE_ROLE, _oldManager)) {
      _revokeRole(MANAGE_ROLE, _oldManager);
    }
    _setupRole(MANAGE_ROLE, _newManager);
  }

  /// @notice Set the ethPrice
  function setFinalPrice() external onlyRole(MANAGE_ROLE) {
      (
          /*uint80 roundID*/,
          int price,
          /*uint startedAt*/,
          /*uint timeStamp*/,
          /*uint80 answeredInRound*/
      ) = priceFeed.latestRoundData();
      ethPrice = price;
      priceSetAt = _currentTime();
      int diff = price;
      int closestGuess = price;
      for (uint i=0; i<guesses.length; i++) {
        int guess = guesses[i];
        int priceDiff = _abs(guess - price);
        if (priceDiff < diff) {
          diff = priceDiff;
          closestGuess = guess;
        }
      }
      winningGuess = closestGuess;
  }

  /// @notice Start a new round
  function nextRound() external onlyRole(MANAGE_ROLE) {
      roundId++;
      roundStartedAt = _currentTime();
      ethPrice = 0;
      winningGuess = 0;
  }

  /* ============ Internal Functions ============ */
  function _abs(int x) internal pure returns (int) {
    return x >= 0 ? x : -x;
  }

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
