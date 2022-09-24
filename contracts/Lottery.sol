// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

error Lottery__NotEnougETHEntered();
error Lottery__TransferFailed();

contract Lottery is VRFConsumerBaseV2{

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

  // Events
  event LotteryEnter(address);
  event RequestedLotteryWinner(uint256 indexed requestId);
  event WinnerPicked(address indexed winner);

  constructor(
    address vrfCoordinatorV2, 
    uint256 _entranceFee, 
    bytes32 _gasLane,
    uint64 _subscriptionId,
    uint32 _callbackGasLimit
  ) VRFConsumerBaseV2(vrfCoordinatorV2) {
    entranceFee = _entranceFee;
    vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
    gasLane = _gasLane;
    subscriptionId = _subscriptionId;
    callbackGasLimit = _callbackGasLimit;
  }

  function enterLottery() public payable {
    //require(msg.value >= entranceFee, "Not enough ETH!");
    if(msg.value < entranceFee) {
      revert Lottery__NotEnougETHEntered();
    }
    players.push(payable(msg.sender));
    emit LotteryEnter(msg.sender);
  }

  function requestRandomWinner() external {
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
}