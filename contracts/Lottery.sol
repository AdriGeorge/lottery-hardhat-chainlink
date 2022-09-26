// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

error Lottery__NotEnougETHEntered();
error Lottery__TransferFailed();
error Lottery__NotOpen();
error Lottery__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 lotteryState);

/** @title A sample Lottery Contract
 *  @author AdriGeorge
 *  @dev This implements Chainlink VRF v2 and Chainlink Keepers
 */
contract Lottery is VRFConsumerBaseV2, KeeperCompatibleInterface {
  // Type
  enum LotteryState {
    OPEN,
    CALCULATING
  } //uint256 0 = OPEN, 1 = CALCULATING

  // State variable
  uint256 private immutable entranceFee;
  address payable[] private players;
  VRFCoordinatorV2Interface private immutable vrfCoordinator;
  bytes32 private immutable gasLane;
  uint64 private immutable subscriptionId;
  uint16 private constant REQUEST_CONFIRMATION = 3;
  uint32 private immutable callbackGasLimit;
  uint32 private constant NUM_WORDS = 1;

  // Lottery variables
  address private recentWinner;
  LotteryState private lotteryState;
  uint256 private lastTimeStamp;
  uint256 private immutable interval;

  // Events
  event LotteryEnter(address);
  event RequestedLotteryWinner(uint256 indexed requestId);
  event WinnerPicked(address indexed winner);

  constructor(
    address vrfCoordinatorV2, //contract
    uint256 _entranceFee, 
    bytes32 _gasLane,
    uint64 _subscriptionId,
    uint32 _callbackGasLimit,
    uint256 _interval
  ) VRFConsumerBaseV2(vrfCoordinatorV2) {
    entranceFee = _entranceFee;
    vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
    gasLane = _gasLane;
    subscriptionId = _subscriptionId;
    callbackGasLimit = _callbackGasLimit;
    lotteryState = LotteryState.OPEN;
    lastTimeStamp = block.timestamp;
    interval = _interval;
  }

  function enterLottery() public payable {
    //require(msg.value >= entranceFee, "Not enough ETH!");
    if(msg.value < entranceFee) {
      revert Lottery__NotEnougETHEntered();
    }
    if(lotteryState != LotteryState.OPEN){
      revert Lottery__NotOpen();
    }
    players.push(payable(msg.sender));
    emit LotteryEnter(msg.sender);
  }

  /**
   * This is the function that the ChainLink keeper nodes call
   * return true if:
   * 1: The time interval should have passed
   * 2: The lottery should have at least 1 player
   * 3: Our subscription is founded with LINK
   * 4: The lottery should be in "open" state
   */
  function checkUpkeep(bytes memory /*checkData*/) public override returns (bool upkeepNeeded, bytes memory /*performData*/){
    bool isOpen = (LotteryState.OPEN == lotteryState);
    bool timePassed = ((block.timestamp - lastTimeStamp) > interval);
    bool hasPlayer = (players.length > 0);
    bool hasBalance = (address(this).balance > 0);
    upkeepNeeded = (isOpen && timePassed && hasPlayer && hasBalance);
  }

  function performUpkeep(bytes calldata /*calldata*/) external override{
    (bool upkeepNeeded, ) = checkUpkeep("");
    if(!upkeepNeeded) {
      revert Lottery__UpkeepNotNeeded(address(this).balance, players.length, uint256(lotteryState));
    }
    lotteryState = LotteryState.CALCULATING;
    uint256 requestId = vrfCoordinator.requestRandomWords(
      gasLane, //keyHash
      subscriptionId, // subscriptionId on chainlink
      REQUEST_CONFIRMATION, // how many blocks for confirmation
      callbackGasLimit,
      NUM_WORDS //how many random words
    );
    emit RequestedLotteryWinner(requestId);
  }

  function fulfillRandomWords(uint256, /* requestId */ uint256[] memory randomWords) internal override {
    uint indexOfWinner = randomWords[0] % players.length;
    recentWinner = players[indexOfWinner];
    lotteryState = LotteryState.OPEN;
    players = new address payable[](0);
    lastTimeStamp = block.timestamp;
    (bool success, ) = recentWinner.call{value: address(this).balance}("");
    if(!success){
      revert Lottery__TransferFailed();
    }
    emit WinnerPicked(recentWinner);
  }

  function getEntranceFee() public view returns(uint256) {
    return entranceFee;
  }

  function getPlayer(uint256 index) public view returns(address) {
    return players[index];
  }

  function getRecentWinner() public view returns(address) {
    return recentWinner;
  }

  function getLotteryState() public view returns(LotteryState) {
    return lotteryState;
  }

  function getNumWords() public pure returns(uint256) {
    return NUM_WORDS;
  }

  function getNumPlayers() public view returns(uint256) {
    return players.length;
  }

  function getLatestTimestamp() public view returns(uint256) {
    return lastTimeStamp;
  }

  function getRequestConfirmations() public pure returns(uint256) {
    return REQUEST_CONFIRMATION;
  }

  function getInterval() public view returns(uint256) {
    return interval;
  }
}