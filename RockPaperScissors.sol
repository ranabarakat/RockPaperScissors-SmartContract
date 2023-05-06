// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;
contract RockPaperScissors {
    struct Participant {
        bytes32 commitment;
        bool played;
        bool revealed;
        uint deposit; // to ensure that participants follow the protocol till the end
                      // in case any of them aborts, the other participant gets the deposit of the aborted participant
    }

    address payable[] beneficiaries; // addresses of participants

    uint public commitingEnd;
    uint public revealEnd;
    bool public ended;
    address payable public  contestmanager;
    mapping(address => Participant) participants;
    mapping(address => uint) moves; // mapping of moves by player address
    uint public reward;

    event GameEnded(address winner);

    error TooEarly(uint time);
    error TooLate(uint time);
    error giveRewardAlreadyCalled();

    modifier onlyBefore(uint time) {
        if (block.timestamp >= time) revert TooLate(time - block.timestamp);
        _;
    }
    modifier onlyAfter(uint time) {
        if (block.timestamp <= time) revert TooEarly(time - block.timestamp);
        _;
    }

    constructor(
        uint commitingTime,
        uint revealTime,
        address payable participant1, 
        address payable participant2
    ) payable{
        contestmanager = payable(msg.sender);
        reward = msg.value;
        beneficiaries = [participant1,participant2];
        commitingEnd = block.timestamp + commitingTime;
        revealEnd = commitingEnd + revealTime;
        // revealEnd = block.timestamp + revealTime;

        require(msg.value>0,"Value cannot be 0!");
        require(!(msg.sender==participant1) && !(msg.sender==participant2),"Contest manager cannot be a participant!");
        
    }

    function computeComm(uint value, bytes32 secret) 
        external 
        pure 
        returns (bytes32){
        return keccak256(abi.encodePacked(value, secret));
    }

    function play(bytes32 commitment)
        external payable
        onlyBefore(commitingEnd)
    {
        Participant storage sender = participants[msg.sender];
        require(!(msg.sender==contestmanager), "Contest manager does not play.");
        require((msg.sender==beneficiaries[0]) || (msg.sender==beneficiaries[1]) , "This address is not allowed to play.");
        require(!sender.played, "Player already committed.");
        // require(msg.value>0,"The deposit value cannot be 0!");
        require(msg.value <= address(msg.sender).balance, "Deposit amount exceeds participant balance.");
        require(msg.value>=reward/2,"The deposit value must be at least half the reward value.");
        // require(choice<3, "Invalid move.");
        sender.played = true;
        // sender.move = choice;
        sender.commitment = commitment;
        sender.deposit = msg.value;
    }

    function reveal(
        uint move,
        bytes32 secret
    )
        external
        onlyAfter(commitingEnd)
        onlyBefore(revealEnd)
    {
        Participant storage player = participants[msg.sender];
        require((msg.sender==beneficiaries[0]) || (msg.sender==beneficiaries[1]) , "This address is not allowed to play.");
        require(move<3, "Invalid move.");
        require(player.commitment == keccak256(abi.encodePacked(move, secret)),"Values do not match the commitment!");
        payable(msg.sender).transfer(player.deposit);
        moves[msg.sender] = move;
        player.revealed = true;
        player.commitment = bytes32(0);
    }

    function giveReward()
        external
        onlyAfter(revealEnd)
    {
        if (ended) revert giveRewardAlreadyCalled();
        ended = true;
        require(msg.sender==contestmanager,"Only contest manager is allowed to call this function.");

       Participant storage p1 =  participants[beneficiaries[0]];
        Participant storage p2 =  participants[beneficiaries[1]];

        uint p1move = moves[beneficiaries[0]];
        uint p2move = moves[beneficiaries[1]];
        
        if (!p1.revealed && !p2.revealed) {
            // none of them revealed, return their deposits
            beneficiaries[0].transfer(p1.deposit);
            beneficiaries[1].transfer(p2.deposit);
            // protocol was not succcesful, refund the manager
            contestmanager.transfer(reward);
        } else if (!p1.revealed) {
            // p2 revealed but p1 did not, so p2 gets p1's deposit
            beneficiaries[1].transfer(p1.deposit);
            // protocol was not succcesful, refund the manager
            contestmanager.transfer(reward);
        } else if (!p2.revealed) {
            // p1 revealed but p2 did not, so p1 gets p2's deposit
            beneficiaries[0].transfer(p2.deposit);
            // protocol was not succcesful, refund the manager
            contestmanager.transfer(reward);
        } else {
            if (p1move == p2move) {
                beneficiaries[0].transfer(reward / 2);
                beneficiaries[1].transfer(reward / 2);
                emit GameEnded(beneficiaries[0]);
                emit GameEnded(beneficiaries[1]);


            } else {
            for (uint i = 0; i < 3; i++) {
                // rock vs paper, paper vs scissors, scissors vs rock => 2nd participant wins
                if (p1move == i && p2move == (i + 1) % 3) {
                    beneficiaries[1].transfer(reward);
                    emit GameEnded(beneficiaries[1]);

                // paper vs rock, scissors vs paper, rock vs scissors => 1st participant wins
                } else if (p2move == i && p1move == (i + 1) % 3) {
                    beneficiaries[0].transfer(reward);
                    emit GameEnded(beneficiaries[0]);

                }
            }
        }
    }

    // Reset the game state
    p1.played = false;
    p2.played = false;
    p1.revealed = false;
    p2.revealed = false;
    moves[beneficiaries[0]] = 0;
    moves[beneficiaries[1]] = 0;
    }
}
/* SAMPLE TEST CASE */ 
/* Contest manager address: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4

   --DEPLOY--

   COMMITINGTIME: 120 (2 min)
   REVEALTIME: 120 (2 min)
   PARTICIPANT1: 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
   PARTICIPANT2: 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
   (Reward must also be provided in the value field)

   --COMMIT PHASE--

   Participant1 computeComm arguments:
   value: 1 (i.e paper)
   secret: 0x000000000000000000000000000000000000000000000000000000000000abcd
   (result of computeComm() is copied in the play() function along with a deposit of at least reward/2)
   Participant2 computeComm arguments:
   value: 2 (i.e scissors)
   secret: 0x000000000000000000000000000000000000000000000000000000000000aaaa
   (result of computeComm() is copied in the play() function along with a deposit of at least reward/2)

    --REVEAL PHASE--

    Participant1 reveal arguments:
    move: 1
    secret: 0x000000000000000000000000000000000000000000000000000000000000abcd
    (deposit should be refunded in this case)
    Participant2 reveal arguments:
    move: 2
    secret: 0x000000000000000000000000000000000000000000000000000000000000aaaa
    (deposit should be refunded in this case)

    --REWARD PHASE--
    ONLY MANAGER CALLS THIS FUNCTION
    Reward must be transferred to participant2 since he is the winner. */


