pragma solidity ^0.4.9;

import "./BiotsToken.sol";



contract SimpleForward is ERC223Token{
    
    /*****
     * BASICS
     * ***/
    
    //our company which created the fitness app, the admin
    address public administration;
    uint index;
    uint prevTestTime;
    
    //consturtor
    function SimpleForward() public{
        administration = msg.sender;
        index = 0;
        prevTestTime = now;
    }
  
    struct Participant {
      uint fitnessScore;
      //TODO: (if time) these data could be accessed with oraclize; possible more data
      //another possible smaller idea instead of steps: activity level
      uint steps; //number of steps overall
      uint prevSteps; //number of steps in previous intervall
      uint prevTime; //time measured at previous intervall
      uint prevDif; //previous time difference in minutes
      uint tokensBetted; //number of tokens which were betted
    }
    
    //stores a "Participant" struct for each possible address
    mapping(address => Participant) public participants;
    
    // map ID to address 
    mapping (uint => address) public participantsIndex;
    
    
    //TODO: (if time) we need the admin to call testFitnessScore regularly automatically in all cases
    //ideally around once per week or day
    //could be done with calclulating used blocks in euthereum, for examample (or participants, other smart contracts)
    //in the best case once at the same time every week, could maybe work with some event
    //currently no time to implement
    //TODO (if time) alternatively, a participant could notify the administration to test his score and give him tokens
    
  
    //new participant is added to the programm
    function createNewParticipant(address participant) public {
          //TODO (if time) only enabling Participants to take place once
          require((msg.sender == administration));
          participantsIndex[index++] = participant;
          balances[participant] = 10000; //10^4
          totalSupply += 10000; //10^4
          collectData(participant);//to have a starting point
    }
    
    /*****
     * OPTIONS TO RECEIVE TOKENS BY PARTICIPANTS, BASED ON SOME FITNESS DATA AND FORMULAS
     * ***/
  
    //administration tests the fitness score of each participant and distributes tokens according to some formulas
    function testFitnessScore() public {
        //TODO: (if time) huge parts could be done with oraclize to make calculations less expensive
        //TODO: (if time) distribution of coins could also be done with more sophisticated formulas according to theoretical work
        //TODO: (if time) optimizing array structure for more efficient execution
        //require((now - prevTestTime) / 1 days > 6);//at least around one week passed, commented out because testing
        require(msg.sender == administration);
        for(uint i = 0; i < index; i++){
            collectData(participantsIndex[i]);
            //each week, 10% of previous tokens is lost to enhance spending
            //TODO (if time) inflation/deflation regulation could be more sophisticated (according to developed theory)
            uint toLose = safeMul(balances[participantsIndex[i]], 9)/10;
            balances[participantsIndex[i]] -= toLose;
            balances[administration] += toLose;
            if(participants[participantsIndex[i]].fitnessScore < 2){
                //don't receive anything; less than around 3000 steps on average per day
            }
            else if(participants[participantsIndex[i]].fitnessScore < 4){
                transfer(participantsIndex[i], (participants[participantsIndex[i]].fitnessScore)*1000*participants[participantsIndex[i]].prevDif , 'x', "0");
            }else if(participants[participantsIndex[i]].fitnessScore < 6){
                //TODO: (if time) adding useful data instead of 'x' and "0" according to erc223 standards
                transfer(participantsIndex[i], 4*1000*participants[participantsIndex[i]].prevDif , 'x', "0");
                transfer(participantsIndex[i], (participants[participantsIndex[i]].fitnessScore-4)*750*participants[participantsIndex[i]].prevDif , 'x', "0");
            }else if(participants[participantsIndex[i]].fitnessScore < 8){
                transfer(participantsIndex[i], 4*1000*participants[participantsIndex[i]].prevDif , 'x', "0");
                transfer(participantsIndex[i], 2*750*participants[participantsIndex[i]].prevDif , 'x', "0");
                transfer(participantsIndex[i], (participants[participantsIndex[i]].fitnessScore-6)*500*participants[participantsIndex[i]].prevDif , 'x', "0");
            }else{
                transfer(participantsIndex[i], 4*1000*participants[participantsIndex[i]].prevDif , 'x', "0");
                transfer(participantsIndex[i], 2*500*participants[participantsIndex[i]].prevDif , 'x', "0");
                transfer(participantsIndex[i], 2*750*participants[participantsIndex[i]].prevDif , 'x', "0");
                transfer(participantsIndex[i], (participants[participantsIndex[i]].fitnessScore-8)*250*participants[participantsIndex[i]].prevDif , 'x', "0");
            }
        }
        prevTestTime = now;
        getWinner();
    }
    
    //collects fitness data from a participant and calculates its fitnessScore
    function collectData(address participant) public {
        //TODO (if time) data set and fitnessScore calculation could be a lot more complex
        //i. e. according to the theoretical work on paper
        //TODO (if time) collecting data (steps) with oraclize from an URL
        //currently some basic data for testing purpusos
        //fitnessScore enables better generalization instead of only working with the steps
        participants[participant].prevSteps = participants[participant].steps;
        participants[participant].steps = participants[participant].steps + 1007;
        //could also calculating with days, but they are equivalent
        //currently minutes because it makes debugging easier
        uint minutesPassed = (now - participants[participant].prevTime)/(1 minutes);
        participants[participant].prevTime = now;
        uint stepsMade = participants[participant].steps - participants[participant].prevSteps;
        //some inaccuracies because of simplification, but they are small overall
        if(minutesPassed == 0){
            minutesPassed++;
        }
        participants[participant].prevDif = minutesPassed;
        participants[participant].fitnessScore = stepsMade / minutesPassed;
    }
    
    /*****
     * OPTIONS TO USE THE TOKENS BY THE PARTICIPANTS
     * CURRENTLY A SIMPLE WINNER TAKES ALL BETTING SYSTEM, BUT COULD BE MORE SOPHISTICATED
     * ***/
    
    //participants can use there tokens on betting
    //there's always one winner each week (each new measurement of fitnessScore)
    //TODO (if time) adding opprotunity to bet on various thing
    //TODO (if time) adding more paying and receiving opportunities according to theoretical work
    function betTokens(uint _value) public {
        require(balances[msg.sender] >= _value);
        transfer(administration, _value, 'x', "0");
        participants[msg.sender].tokensBetted += _value;
    }
    
    //saves the winners in the blockchain
    //TODO: could also add other data, i. e. which week and prize hashed
    event bettingEnded(uint weeklyWinner);
    
    //calculates the winner: the one who bets most wins
    //note that if they don't win, they don't get any money back, because it's a bet, at the end it's zero
    //TODO: (if time) randomized decision on who the winner is, possibly with oraclize
    function getWinner() public {
        require(msg.sender == administration);
        uint curMax = 0;
        uint curInd = index;
        for(uint i = 0; i < index; i++){
            if(participants[participantsIndex[i]].tokensBetted > curMax){
                curMax = participants[participantsIndex[i]].tokensBetted;
                curInd = i;
            }
            participants[participantsIndex[i]].tokensBetted = 0;
        }
        if(curInd < index){
            bettingEnded(curInd);
        }
    }
    
    
    
    /*****
     * SOME FUNCTIONS WHICH ALLOW THE USERS TO GET SPECIFIC DATA
     * ***/
    
    //returns current balance from caller
    function getBalance() public view returns (uint _balance){
        return balances[msg.sender];
    }
    
    //returns current fitnessScore from caller
    function getFitnessScore() public view returns (uint _fitnessScore){
        return participants[msg.sender].fitnessScore;
    }
    
    //returns number of steps in last period
    function getStepsOverall() public view returns (uint _stepsOverall){
        return participants[msg.sender].steps;
    }
    
    //returns number of steps in last period
    function getPrevSteps() public view returns (uint _prevSteps){
        return participants[msg.sender].prevSteps;
    }
    
    //returns time in last measureing periods, currently in minutes
    function getPrevDif() public view returns (uint _prevDif){
        return participants[msg.sender].prevDif;
    }
    
}
