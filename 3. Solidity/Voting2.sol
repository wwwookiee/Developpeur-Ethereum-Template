// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

error WrongWorkflowStatus();

contract Voting is Ownable {

    /**
     * Emitted when a member is registered as Voter.
     *
     * `voterAddress` is the address of the member allowed to vote.
     */
    event VoterRegistered(address voterAddress); 

    /**
     * Emitted when `workflowStatus` is updated.
     *
     * `previousStatus` is the previous stage of voting before the admin trigger a new stage.
     */
    event WorkflowStatusChange(WorkflowStatus indexed previousStatus, WorkflowStatus indexed newStatus);

    /**
     * Emitted when a `proposal` is submitted by a Voter.
     *
     * `proposalId` is the index of the array `proposals` where proposal is stored.
     */
    event ProposalRegistered(uint256 proposalId);

    /**
     * Emitted when a Voter has Voted.
     *
     * `voter` is the address of the Voter.
     * `proposalId` is the id of the chosen proposal by the Voter.
     *
     * Note : This can display in front-end who votes for a proposal, alternatively a function returning all the voters can be implemented.
     */ 
    event Voted (address voter, uint256 indexed proposalId);

    /**
    *   Structur for Voter
    *
    * `isRegistered` is the element for whitlisting a voter and make him/her able to vote
    * `hasVoted`define if the voter has given a vote or not : default is false
    *  `votedProposalId` is a reference to the id of the proposal stored in array `proposals`
    */

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint256 votedProposalId;
    }

    /**
    *   Structur for Proposal
    *
    * `description` is the string that store the description of the proposal.
    * `voteCount` define the amount of votes received by the proposal.
    */
    struct Proposal {
        string description;
        uint256 voteCount;
    }

    /**
    * Enumeration define the differents stage of the voting
    *
    * Phase 1 : `RegisteringVoters` is the default state, admin is able to register voters.
    * Phase 2 : `ProposalsRegistrationStarted` : voters are allowed to start submiting their proposals.
    * Phase 3 : `ProposalsRegistrationEnded` : end of submiting proposals stage.
    * Phase 4 : `VotingSessionStarted` : voters are allowed to vote for a proposal.
    * Phase 5 : `VotingSessionEnded` : end of the voting stage.
    * Phase 6 : `VotesTallied` : has counted the votes to elect a winning proposal.
    * Phase 7 : `NoConsensusFound` : no winning proposal have been found. This stage could lead to a new vote (not implemented yet)
    */
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied,
        NoConsensusFound
    }

    uint256 winningProposalId;

    WorkflowStatus public workflowStatus;

    mapping (address => Voter) public voters;

    // Using an array for the loops.
    Proposal[] public proposals;
    Proposal[] private _tmpProposals = proposals;

    // Constructor only for testing purpose.
    constructor() {
        voters[0x5B38Da6a701c568545dCfcB03FcB875f56beddC4].isRegistered = true;
        workflowStatus = WorkflowStatus.NoConsensusFound;
        proposals.push(Proposal("test2", 7));
        proposals.push(Proposal("test6", 3));
        proposals.push(Proposal("test4", 1));
        proposals.push(Proposal("test5", 4));
        proposals.push(Proposal("test3", 7));
        proposals.push(Proposal("test7", 0));
        proposals.push(Proposal("test1", 5));
    }

    /**
    * Sessions starters, can only be called by the contract's owner.
    * `RegisteringVoters` status is set by default, each other stage of voting are individualy and explicitly writen to ensure trust in voting system. 
    */

    function startProposalsRegistration() external onlyOwner{
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "You are not allowed to do so at this stage. Expected `WorkflowStatus.RegisteringVoters`.");
         _setWorkflowStatus (workflowStatus, WorkflowStatus.ProposalsRegistrationStarted);       
    }

    function endProposalsRegistration() external onlyOwner{
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "You are not allowed to do so at this stage. Expected `WorkflowStatus.ProposalsRegistrationStarted`.");
        _setWorkflowStatus (workflowStatus, WorkflowStatus.ProposalsRegistrationEnded);
    }

    function startVotingSession() external onlyOwner{
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, "You are not allowed to do so at this stage. Expected `WorkflowStatus.ProposalsRegistrationEnded`.");
        _setWorkflowStatus (workflowStatus, WorkflowStatus.VotingSessionStarted);
    }

    function endVotingSession() external onlyOwner{
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "You are not allowed to do so at this stage. Expected `WorkflowStatus.VotingSessionStarted`.");
        _setWorkflowStatus (workflowStatus, WorkflowStatus.VotingSessionEnded);
    }

    /**
    * Update `workflowStatus` and emit an `event WorkflowStatusChange`.
    */

    function _setWorkflowStatus (WorkflowStatus _previousStatus, WorkflowStatus _newStatus) private {
        workflowStatus = _newStatus;
        emit WorkflowStatusChange(_previousStatus, _newStatus);
    }

    /**
    * Register voters by adding their addresse into voters mapping.
    */

    function registerVoter(address _address) external onlyOwner {
        /* 
        * Variation of require with revert using error.
        * Check if `workflowStatus` is set to `ProposalsRegistrationStarted`. If condition is not met it trigger the `error WrongWorkflowStatus()`.
        */
        if(workflowStatus != WorkflowStatus.RegisteringVoters) { revert WrongWorkflowStatus(); }
        voters[_address].isRegistered = true;
        voters[_address].hasVoted = false;
        emit VoterRegistered(_address);
    }

    /**
    * Proposals registration by pushing new proposals into `proposals` array.
    */

    function registerProposal(string memory _proposal) external onlyRegisteredVoter{
        // Check if `workflowStatus` is set to `ProposalsRegistrationStarted`
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "You are not allowed to do so at this stage. Expected `WorkflowStatus.ProposalsRegistrationStarted`.");
        // Check if `_proposal` is not empty
        require(bytes(_proposal).length > 0, "Proposal is too short"); 
        proposals.push(Proposal(_proposal, 0));
        emit ProposalRegistered(proposals.length-1);
    }

    /**
    * Allow voters to vote for Proposals by registering the `_proposalId` into `voters` mapping.
    */

    function voteForProposal(uint256 _proposalId) public onlyRegisteredVoter{
        //check if the voter has already voted
        require(!voters[_msgSender()].hasVoted, "You have already voted.");
        // Check if `workflowStatus` is set to `VotingSessionStarted`.
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "You are not allowed to do so at this stage. Expected `WorkflowStatus.VotingSessionStarted`.");
        //Check if `_proposalId` exist
        require(_proposalId >= 0 && _proposalId < proposals.length, "This proposal id doesn't exist.");
        voters[_msgSender()].hasVoted = true;
        voters[_msgSender()].votedProposalId = _proposalId;
        proposals[_proposalId].voteCount++;  
        emit Voted(_msgSender(),_proposalId);
    }

    /**
    * Tally votes and set the "winner" vote. they are 2 scenarios :
    * 1. There is no equality > winner is elected and `VotesTallied` is set as workflowStatus
    * 2. There is an equality > no winner is elected and `NoConsensusFound` is set as workflowStatus
    *
    *
    * Note : To Do : `NoConsensusFound` status could be used to launch again a voting session between all the "winners"
    */

    function tallyVotes() external onlyOwner {
        // Check if `workflowStatus` is set to `VotingSessionEnded`.
        require(workflowStatus == WorkflowStatus.VotingSessionEnded, "You are not allowed to do so at this stage. Expected `WorkflowStatus.VotingSessionEnded`.");
        // Check if there are proposals registered.
        require(proposals.length > 0, "No proposal registered."); 
        bool equality;
        uint256 maxVotes = proposals[0].voteCount;
        for (uint256 i = proposals.length - 1; i >= 1; i--) {
            if (proposals[i].voteCount == maxVotes) {
                equality = true;
            } else if (proposals[i].voteCount > maxVotes) {
                equality = false;
                maxVotes = proposals[i].voteCount;
                winningProposalId = i;
            }
        }
        if (equality) {
            _setWorkflowStatus(workflowStatus, WorkflowStatus.NoConsensusFound);
        } else {
            _setWorkflowStatus(workflowStatus, WorkflowStatus.VotesTallied);
        }        
    }

    /**
    * Returns the winning proposal 
    */

    function getWinnerPorposal() external view returns(Proposal memory _winner) { 
        string memory _errorMsg = (workflowStatus == WorkflowStatus.NoConsensusFound) ? "No consensus were found." : "You are not allowed to do so at this stage. Expected `WorkflowStatus.VotesTallied`.";
        // Check if `workflowStatus` is set to `VotesTallied`.
        require(workflowStatus == WorkflowStatus.VotesTallied, _errorMsg);
        return proposals[winningProposalId];
    }

    function restarVotingSession() external onlyOwner{
        require(workflowStatus == WorkflowStatus.NoConsensusFound, "You are not allowed to do so at this stage. Expected `WorkflowStatus.NoConsensusFound`.");
        for (uint256 i = proposals.length - 1; i >= 0; i--) {
            if (proposals[i].voteCount < proposals[winningProposalId].voteCount) {
                _tmpProposals[i] = proposals[_tmpProposals.length - 1];
                _tmpProposals.pop();
            }
        }
        proposals = _tmpProposals;
        workflowStatus = WorkflowStatus.VotingSessionStarted;
        _setWorkflowStatus (workflowStatus, WorkflowStatus.VotingSessionStarted);
    }

    /**
    * Modifier allowing voting only for the registered members stored in `voters` mapping.
    */

    modifier onlyRegisteredVoter() {
        require( voters[_msgSender()].isRegistered , "Only the authorised addresses are allowed to vote");
        _; 
    }
}

