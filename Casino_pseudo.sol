//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";


contract Casino is Ownable /*, VRFConsumerBaseV2*/ {
    event Deposit (address depositor, uint256 value, uint256 firstTicket, uint256 lastTicket);
    event RouletteStatusUpdate(ROULETTE_STATUS status);
    event NewWinner(address winner, uint256 randomness, uint256 winnerTicket, uint256 winningValue);
 

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
  
    constructor(){
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
        randomness = uint256(keccak256(abi.encodePacked(
            msg.sender, 
            block.difficulty, 
            block.timestamp 
            )));
        winnerTicket = (randomness % currentMaxTicket) + 1;
        emit RouletteStatusUpdate(ROULETTE_STATUS.CALCULATING);
        sendWinnings();
        emit NewWinner(winner, randomness, winnerTicket, winningValue);
        clearPreviousRound();
        roulette_status = ROULETTE_STATUS.ENDED;
        emit RouletteStatusUpdate(ROULETTE_STATUS.ENDED);
    }

    function sendWinnings() internal {
        for (uint256 i = 0; i < currentBetCount;i++) {
            if (tickets[i].firstTicket <= winnerTicket && tickets[i].lastTicket >= winnerTicket) {
                winner = payable(tickets[i].participant);
                break;
            }
        }
        winningValue = address(this).balance;
        winner.transfer(winningValue);
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
    }

    function emergencyWithdrawall() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

}
