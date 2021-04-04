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
        uint256 totalApprovals;
        uint256 totalDenials;
        uint256 remainingVotes;
    }

    modifier requireOwnership {
        bool isOwner = false;
        for (uint i = 0; i < contractOwners.length;) {
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

    // Instantiates initial owners
    constructor(address[] memory _owners) {
        require(_owners.length > 0, "owners required");
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            contractOwners.push(owner);
        }
    }

    function getOwners() public view returns (address[] memory) {
        return contractOwners;
    }

    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }


    // Views contract's eth balance
    function viewTotalEth() public view returns (uint256 unformattedFunds, uint256 formattedFunds) {
        return (address(this).balance, address(this).balance / (10**18));
    }

    // Allows anyone to view the status of a tx
    function getTx(uint256 txId) external view returns(
        uint256 timeOfFinalisation,
        string memory status,
        address to,
        uint256 amount,
        uint256 totalApprovals,
        uint256 totalDenials,
        uint256 remainingVotes
    ) {
        return (
            transactions[txId].timeOfFinalisation,
            transactions[txId].status,
            transactions[txId].to,
            transactions[txId].amount,
            transactions[txId].totalApprovals,
            transactions[txId].totalDenials,
            transactions[txId].remainingVotes
        );
    }

    function donateEth() public payable {
        // Call returns a boolean value indicating success or failure.
        // This is the current recommended method to use.
        (bool success, ) = address(this).call{value: msg.value}("");
        require(success, "tx failed");
    }

    // Allows owners to create transactions
    function createTx(address to, uint256 amount) external requireOwnership returns(address, uint256) {
        transactions.push(transaction({
            timeOfCreation: block.timestamp,
            timeOfFinalisation: (block.timestamp + 7 days),
            status: "pending",
            to: to, 
            amount: amount, 
            totalApprovals: 0,
            totalDenials: 0,
            remainingVotes: contractOwners.length
        }));
    }

    // Allows owners to vote approve a tx
    function approveTx(uint256 txId) external requireOwnership hasntVoted(txId) {
        hasVoted[msg.sender][txId] = true;
        transactions[txId].totalDenials += 1;
        transactions[txId].remainingVotes -= 1;
    }

    // Allows owners to vote deny a tx
    function denyTx(uint256 txId) external requireOwnership hasntVoted(txId) {
        hasVoted[msg.sender][txId] = true;
        transactions[txId].totalDenials += 1;
        transactions[txId].remainingVotes -= 1;
    }

    function executeTx(uint256 txId) external requireOwnership returns (string memory) {
        bool _isConfirmed = calculateStatus(txId);
        
        if (_isConfirmed == true) {
            (bool success, ) = transactions[txId].to.call{value: transactions[txId].amount}("");
            require(success, "tx failed");
            return "tx was successfully executed";
        } else {
            return "tx was not executed";
        }
    }

    // Calculates if approved or denied
    function calculateStatus(uint256 _txId) internal returns(bool _isConfirmed) {
        require(
            transactions[_txId].timeOfFinalisation < block.timestamp || transactions[_txId].remainingVotes == 0,
            "transaction in process, wait until finalisation occurs"
        );

        if(transactions[_txId].totalApprovals > transactions[_txId].totalDenials) {
            transactions[_txId].status = "approved";
            isConfirmed[_txId] = true;
            _isConfirmed = true;
        } else if (transactions[_txId].totalApprovals <= transactions[_txId].totalDenials) {
            transactions[_txId].status = "denied";
            isDenied[_txId] = true;
            _isConfirmed = false;
        }
    }

    // Allows the contract to receive eth
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }
}
