// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
// import "hardhat/console.sol";

/** 
 * @title RockPaperScissors
 * @dev Implements rock-paper-scissors game to claim a reward
 */
contract RockPaperScissors {

    struct Participant {
        bool played;  // if true, that person chose a move
        uint move;   // index of the chosen move: 0=>rock,1=>paper,2=>scissors
    }

    address public contestmanager;
    uint public reward;
    address payable[] beneficiaries; // addresses of participants

    mapping(address => Participant) participants;

    constructor(address payable participant1, address payable participant2) payable {
        contestmanager = msg.sender;
        reward = msg.value;
        beneficiaries = [participant1,participant2];
        require(msg.value>0,"Value cannot be 0!");
        require(!(msg.sender==participant1) && !(msg.sender==participant2),"Contest manager cannot be a participant!");

    }

  

    function play(uint choice) public {
        Participant storage sender = participants[msg.sender];
        require(!(msg.sender==contestmanager), "Contest manager does not play.");
        require((msg.sender==beneficiaries[0]) || (msg.sender==beneficiaries[1]) , "This address is not allowed to play.");
        require(!sender.played, "Already made a move.");
        require(choice<3, "Invalid move.");
        sender.played = true;
        sender.move = choice;
    }

    function decideWinner() private view
            returns (address winnerAddr)
    {
        Participant storage p1 =  participants[beneficiaries[0]];
        Participant storage p2 =  participants[beneficiaries[1]];

        uint p1move = p1.move;
        uint p2move =p2.move;

        if(p1move == p2move){
            return address(0); // tie
        }

        else{
            for(uint i=0;i<3;i++){
            // rock vs paper, paper vs scissors, scissors vs rock => 2nd participant wins
                if(p1move == i && p2move == (i+1)%3){
                    return beneficiaries[1];
                }
            // paper vs rock, scissors vs paper, rock vs scissors => 1st participant wins
                else if(p2move == i && p1move == (i+1)%3){
                    return beneficiaries[0];
                }
            }

        }
    }

    function claimReward() public 
    {
        Participant storage p1 =  participants[beneficiaries[0]];
        Participant storage p2 =  participants[beneficiaries[1]];
        require(p1.played && p2.played,"Both players must choose a move before proceeding.");
        require(msg.sender==contestmanager,"Only contest manager is allowed to call this function.");
        address winnerAddr = decideWinner();
        if(winnerAddr == address(0)){
            beneficiaries[0].transfer(reward/2);
            beneficiaries[1].transfer(reward/2);
            // console.log("It's a tie!");
        }
        else {
            payable(winnerAddr).transfer(reward);
            // console.log("Winner is: ");
            // console.log(winnerAddr);
        }
        p1.played = false;
        p2.played = false;

    }

}