//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Casino is Ownable, VRFConsumerBaseV2 {
    event Deposit (address depositor, uint256 value, uint256 firstTicket, uint256 lastTicket);
    event RouletteStatusUpdate(ROULETTE_STATUS status);
    event NewWinner(address winner, uint256 requestId, uint256 randomness, uint256 winnerTicket, uint256 winningValue);
    event RequestReceived(uint256 randomWords);

    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN;
    uint64 s_subscriptionId;
    address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
    address link = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709;
    bytes32 keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;

    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;
    uint256[] public s_randomWords;
    uint256 public s_requestId;

    struct Ticket {
        address participant;
        uint256 firstTicket;
        uint256 lastTicket;
    }
    Ticket[] public tickets;

    uint256 public currentMaxTicket;
    uint256 winnerTicket;
    address payable winner;
    uint256 public currentBetCount = 0;
    uint256 randomness;
    uint256 winningValue;

    uint256 public MIN_BET = 10000 * (10 ** 9);
    uint256 public MAX_BET_COUNT = 100;


    enum ROULETTE_STATUS {
        STARTED,
        ENDED,
        CALCULATING
    }
    ROULETTE_STATUS public roulette_status;
  
    constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link);
        s_subscriptionId = subscriptionId;
        roulette_status = ROULETTE_STATUS.ENDED;
    }


    function deposit() public payable {
        require(roulette_status == ROULETTE_STATUS.STARTED, "Roulette isn't started");
        require(msg.value >= MIN_BET, "Bet should be greater than 10,000 gwei");
        require(currentBetCount <= MAX_BET_COUNT, "Can't bet in this round");
        if (currentBetCount < tickets.length) {
            tickets[currentBetCount].participant = msg.sender;
            tickets[currentBetCount].firstTicket = currentMaxTicket+1;
            tickets[currentBetCount].lastTicket = currentMaxTicket+msg.value;
        } else {
            tickets.push(Ticket(
            {
                participant : msg.sender,
                firstTicket : currentMaxTicket+1,
                lastTicket : currentMaxTicket+msg.value
            }
        ));
        }
        emit Deposit(msg.sender, msg.value, currentMaxTicket+1, currentMaxTicket+msg.value);
        currentMaxTicket += msg.value;
        currentBetCount += 1;
    }
    function startRoulette() public onlyOwner {
        roulette_status = ROULETTE_STATUS.STARTED;
        emit RouletteStatusUpdate(ROULETTE_STATUS.STARTED);
    }
    function endRoulette() public onlyOwner {
        require(roulette_status == ROULETTE_STATUS.STARTED, "Roulette isn't started");
        roulette_status = ROULETTE_STATUS.CALCULATING;
        s_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        emit RouletteStatusUpdate(ROULETTE_STATUS.CALCULATING);
    }

    
    function fulfillRandomWords(uint256,uint256[] memory randomWords) internal override {
        winnerTicket = (randomWords[0] % currentMaxTicket) + 1;
        s_randomWords = randomWords;
        emit RequestReceived(randomWords[0]);
    }
    
    function sendWinnings() public onlyOwner {
        for (uint256 i = 0; i < currentBetCount;i++) {
            if (tickets[i].firstTicket <= winnerTicket && tickets[i].lastTicket >= winnerTicket) {
                winner = payable(tickets[i].participant);
                break;
            }
        }
        winningValue = address(this).balance;
        winner.transfer(winningValue);
        emit NewWinner(winner, s_requestId, s_randomWords[0], winnerTicket, winningValue);
        clearPreviousRound();
        roulette_status = ROULETTE_STATUS.ENDED;
        emit RouletteStatusUpdate(ROULETTE_STATUS.ENDED);
    }

    function clearPreviousRound() internal {
        currentMaxTicket = 0;
        for (uint256 i = 0; i < currentBetCount; i++) {
            delete tickets[i];
        }
        currentBetCount = 0;
        winnerTicket = 0;
        winningValue = 0;
        winner = payable(address(0x0000000000000000000000000000000000000000));
        randomness = 0;
        s_randomWords[0] = 0;
        s_requestId = 0;
    }

    function emergencyWithdrawall() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

}
