// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/access/Ownable.sol";

contract Gnaira is ERC20, Ownable {
    mapping(address => bool) private _blacklist;
    mapping(uint256 => Proposal) private _proposals;
    uint256 private _proposalCounter;

    event Blacklisted(address indexed account);
    event Unblacklisted(address indexed account);
    event ProposalCreated(
        uint256 indexed proposalId,
        ProposalType proposalType,
        address indexed account,
        uint256 amount
    );
    event ProposalApproved(
        uint256 indexed proposalId,
        address indexed approver
    );
    event ProposalExecuted(uint256 indexed proposalId);

    enum ProposalType {
        Mint,
        Burn,
        Blacklist,
        Unblacklist
    }

    struct Proposal {
        ProposalType proposalType;
        address account;
        uint256 amount;
        uint256 approvals;
        mapping(address => bool) approvedBy;
        bool executed;
    }

    address[] public approvers;
    uint256 public requiredApprovals;

    constructor(
        string memory name,
        string memory symbol,
        address[] memory initialApprovers,
        uint256 _requiredApprovals
    ) ERC20(name, symbol) {
        require(
            _requiredApprovals > 0 &&
                _requiredApprovals <= initialApprovers.length,
            "Invalid number of required approvals"
        );
        for (uint256 i = 0; i < initialApprovers.length; i++) {
            require(
                initialApprovers[i] != address(0),
                "Approver cannot be the zero address"
            );
            approvers.push(initialApprovers[i]);
        }
        requiredApprovals = _requiredApprovals;
        _mint(msg.sender, 1000000 * 10**decimals()); // Initial supply to owner
    }

    modifier onlyApprover() {
        require(isApprover(msg.sender), "Not an approver");
        _;
    }

    modifier proposalExists(uint256 proposalId) {
        require(proposalId < _proposalCounter, "Proposal does not exist");
        _;
    }

    modifier notExecuted(uint256 proposalId) {
        require(!_proposals[proposalId].executed, "Proposal already executed");
        _;
    }

    function isApprover(address account) public view returns (bool) {
        for (uint256 i = 0; i < approvers.length; i++) {
            if (approvers[i] == account) {
                return true;
            }
        }
        return false;
    }

    function createProposal(
        ProposalType proposalType,
        address account,
        uint256 amount
    ) public onlyApprover returns (uint256) {
        uint256 proposalId = _proposalCounter;
        Proposal storage proposal = _proposals[proposalId];
        proposal.proposalType = proposalType;
        proposal.account = account;
        proposal.amount = amount;
        proposal.executed = false;
        _proposalCounter++;
        emit ProposalCreated(proposalId, proposalType, account, amount);
        return proposalId;
    }

    function approveProposal(uint256 proposalId)
        public
        onlyApprover
        proposalExists(proposalId)
        notExecuted(proposalId)
    {
        Proposal storage proposal = _proposals[proposalId];
        require(
            !proposal.approvedBy[msg.sender],
            "Already approved by this approver"
        );
        proposal.approvedBy[msg.sender] = true;
        proposal.approvals++;
        emit ProposalApproved(proposalId, msg.sender);

        if (proposal.approvals >= requiredApprovals) {
            executeProposal(proposalId);
        }
    }

    function executeProposal(uint256 proposalId)
        internal
        proposalExists(proposalId)
        notExecuted(proposalId)
    {
        Proposal storage proposal = _proposals[proposalId];
        proposal.executed = true;

        if (proposal.proposalType == ProposalType.Mint) {
            _mint(proposal.account, proposal.amount);
        } else if (proposal.proposalType == ProposalType.Burn) {
            _burn(proposal.account, proposal.amount);
        } else if (proposal.proposalType == ProposalType.Blacklist) {
            _blacklist[proposal.account] = true;
            emit Blacklisted(proposal.account);
        } else if (proposal.proposalType == ProposalType.Unblacklist) {
            _blacklist[proposal.account] = false;
            emit Unblacklisted(proposal.account);
        }

        emit ProposalExecuted(proposalId);
    }

    function isBlacklisted(address account) public view returns (bool) {
        return _blacklist[account];
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(!_blacklist[from], "Gnaira: sender is blacklisted");
        require(!_blacklist[to], "Gnaira: recipient is blacklisted");
        super._beforeTokenTransfer(from, to, amount);
    }
}

