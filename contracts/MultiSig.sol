// Developed on 4 April 2021 by Lucus Ra
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.0;

contract MultiSig {
    event Deposit(address indexed sender, uint256 indexed amount, uint256 contractBalance);

    address[] contractOwners;

    mapping(uint => bool) private isConfirmed;
    mapping(uint => bool) private isDenied;
    // key: user, value: txId hasVoted true or default false
    mapping(address => mapping(uint => bool)) private hasVoted;

    transaction[] transactions;

    struct transaction {
        uint256 timeOfCreation;
        uint256 timeOfFinalisation;
        string status;

        address to;
        uint256 amount;

        uint256 totalVotes;

        uint256 totalApprovals;
        uint256 totalDenials;
    }

    modifier requireOwnership {
        bool isOwner = false;
        for (uint256 i = 0; i < contractOwners.length;) {
            if (msg.sender == contractOwners[i]) {
                isOwner = true;
            } else if (i < contractOwners.length) {
                ++i;
            } else {
                revert();
            }
        }
        require(isOwner == true, "you are not an owner");
        _;
    }

    modifier hasntVoted(uint256 txId) {
        require(hasVoted[msg.sender][txId] == false, "you've already voted");
        _;
    }

    constructor(address user1, address user2, address user3) {
        contractOwners.push(user1);
        contractOwners.push(user2);
        contractOwners.push(user3);
    }

    function sendViaCall() public payable {
        // Call returns a boolean value indicating success or failure.
        // This is the current recommended method to use.
        (bool sent, bytes memory data) = address(this).call{value: msg.value}("");
        require(sent, "Failed to send Ether");
    }

    // Views contract's eth balance
    function viewFunds() external view returns (uint256 unformattedFunds, uint256 formattedFunds) {
        return (address(this).balance, address(this).balance / (10**18));
    }

    function calculateStatus(uint256 _txId) internal returns(uint256) { 
        if(transactions[_txId].totalApprovals > transactions[_txId].totalDenials) {
            transactions[_txId].status = "approved";
            transactions[_txId].timeOfFinalisation = block.timestamp;
            isConfirmed[_txId] = true;
        } else if (transactions[_txId].totalApprovals < transactions[_txId].totalDenials) {
            transactions[_txId].status = "denied";
            transactions[_txId].timeOfFinalisation = block.timestamp;
            isDenied[_txId] = true;
        } else if (transactions[_txId].totalApprovals == transactions[_txId].totalDenials) {
            transactions[_txId].status = "draw (equal approval & denial votes), extending by 3 days";
            transactions[_txId].timeOfFinalisation = block.timestamp + 3 days;
        }

    }

    function createTx(address to, uint256 amount) external requireOwnership returns(address, uint256) {
        transactions.push(
            transaction(
                block.timestamp,
                (block.timestamp + 7 days),
                "pending",
                to, 
                amount, 
                0,
                0,
                0
            )
        );
    }

    function approveTx(uint256 txId) external requireOwnership hasntVoted(txId) {
        hasVoted[msg.sender][txId] = true;
        transactions[txId].totalVotes += 1;
        transactions[txId].totalDenials += 1;
    }

    function denyTx(uint256 txId) external requireOwnership hasntVoted(txId) {
        hasVoted[msg.sender][txId] = true;
        transactions[txId].totalVotes += 1;
        transactions[txId].totalDenials += 1;
    }

    function viewTxStatus(uint256 txId) external view returns(string memory status) {
        return transactions[txId].status;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }


}