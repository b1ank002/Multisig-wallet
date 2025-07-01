// SPDX-License-Identifier:MIT
pragma solidity ^0.8.30;

contract VaultMultisig {
    /// @notice The number of signatures required to execute a transaction
    uint256 public quorum;

    /// @notice The array of multisig signers
    address[] public multiSigSignersArray;

    /// @notice The number of transfers executed
    uint256 public transfersCount;

    /// @dev The struct is used to store the details of a transfer
    /// @param to The address of the recipient
    /// @param amount The amount of tokens to transfer
    /// @param approvals The number of approvals that approved the transfer
    /// @param executed Whether the transfer has been executed
    /// @param approved A mapping of signers to their approval status
    struct Transfer {
        address to;
        uint256 amount;
        uint256 approvals;
        bool executed;
        mapping(address => bool) approved;
    }

    /// @notice The mapping of transfer IDs to transfer details
    mapping(uint256 => Transfer) private transfers;

    /// @notice The mapping for verification that address is signer
    mapping(address => bool) public multiSigSigners;

    /// @notice Checks if the array of signers is not empty
    error SingersArrayCantBeEmpty();

    /// @notice The error is thrown when the quorum is greater than the number of signers
    error QuorumGreaterThanSigners();

    /// @notice The error is thrown when the quorum is less than 1
    error QuorumLessThanOne();

    /// @notice The error is thrown when the recipient is address(0)
    error InvalidReceipient();

    /// @notice The error is thrown when the amount is 0
    error InvalidAmount();

    /// @notice The error is thrown when the signer is not a multisig signer
    error InvalidMultisigSigner();

    /// @notice The error is thrown when the transfer is already executed
    /// @param transferId The ID of the transfer
    error TransferAlreadyExecuted(uint256 transferId);

    /// @notice The error is thrown when the signer has already approved the transfer
    /// @param signer The address of the signer
    error SignerAlreadyApproved(address signer);

    /// @notice The error is thrown when the quorum is not reached
    /// @param transferId The ID of the transfer
    error QuorumNotReached(uint256 transferId);

    /// @notice The error is thrown when the balance is not enough
    error InsufficientBalance();

    /// @notice The error is thrown when the transfer fails
    error TransferFailed(uint256 transferId);

    /// @notice The error is thrown when the signer already exists
    /// @param signer The address of the signer
    error SignerAlreadyExists(address signer);

    /// @notice The event is emitted when a transfer is initialized
    /// @param transferId The ID of the transfer
    /// @param to The address of the recipient
    /// @param amount The amount of tokens to transfer
    event TransferInitialized(uint256 indexed transferId, address to, uint256 amount);

    /// @notice The event is emitted when a signer approves a transfer
    /// @param transferId The ID of the transfer
    /// @param signer The address of the signer
    event TransferApproved(uint256 indexed transferId, address signer);

    /// @notice The event is emitted when a transfer is executed
    /// @param transferId The ID of the transfer
    event TransferExecuted(uint256 indexed transferId);

    /// @notice Emitted when the multisig signers are updated
    event MultiSigSignersUpdated();

    /// @notice Emitted when the quorum is updated
    /// @param quorum The new quorum
    event QuorumUpdated(uint256 quorum);

    /// @notice The modifier is used to check if the signer is a multisig signer
    modifier onlyMultiSigner() {
        if (!multiSigSigners[msg.sender]) revert InvalidMultisigSigner();
        _;
    }

    /// @notice Initialize the multisig contract
    /// @param _signers The array of multisig signers
    /// @param _quorum The number of signatures required to execute a transaction
    constructor(address[] memory _signers, uint256 _quorum) {
        if (_signers.length == 0) revert SingersArrayCantBeEmpty();
        if (_quorum > _signers.length) revert QuorumGreaterThanSigners();
        if (_quorum == 0) revert QuorumLessThanOne();

        for (uint256 i = 0; i < _signers.length; i++) {
            address signer = _signers[i];
            if (signer == address(0)) revert InvalidMultisigSigner();
            if (multiSigSigners[signer]) revert SignerAlreadyExists(signer);
            multiSigSigners[signer] = true;
        }

        multiSigSignersArray = _signers;
        quorum = _quorum;
    }

    /// @notice The default fallback function fo receiving ETH
    receive() external payable {}

    /// @notice Updates the list of multisig signers and sets a new quorum
    /// @dev Only callable by all current signers via consensus (i.e., must call from multisig itself)
    /// @param newSigners The new array of signer addresses
    /// @param newQuorum The new required quorum
    function updateSignersAndQuorum(address[] calldata newSigners, uint256 newQuorum) external onlyMultiSigner {
        if (newSigners.length == 0) revert SingersArrayCantBeEmpty();
        if (newQuorum == 0) revert QuorumLessThanOne();
        if (newQuorum > newSigners.length) revert QuorumGreaterThanSigners();

        // Clear old signers
        for (uint256 i = 0; i < multiSigSignersArray.length; i++) {
            multiSigSigners[multiSigSignersArray[i]] = false;
        }

        // Set new signers
        for (uint256 i = 0; i < newSigners.length; i++) {
            address signer = newSigners[i];
            require(signer != address(0), InvalidMultisigSigner());
            if (multiSigSigners[signer]) revert SignerAlreadyExists(signer);
            multiSigSigners[signer] = true;
        }

        multiSigSignersArray = newSigners;
        quorum = newQuorum;
        emit MultiSigSignersUpdated();
        emit QuorumUpdated(newQuorum);
    }

    /// @notice Initialize a transfer
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to transfer
    function InitializeTransfer(address _to, uint256 _amount) external onlyMultiSigner {
        if (_to == address(0)) revert InvalidReceipient();
        if (_amount == 0) revert InvalidAmount();

        uint256 transferId = transfersCount++;
        Transfer storage transfer = transfers[transferId];
        transfer.to = _to;
        transfer.amount = _amount;
        transfer.approvals = 1;
        transfer.executed = false;
        transfer.approved[msg.sender] = true;

        emit TransferInitialized(transferId, _to, _amount);
    }

    /// @notice Approve a transfer
    /// @param transferId The ID of the transfer
    /// @dev Must return true
    function approveTransfer(uint256 transferId) external onlyMultiSigner {
        Transfer storage transfer = transfers[transferId];
        if (transfer.executed) revert TransferAlreadyExecuted(transferId);
        if (transfer.approved[msg.sender]) revert SignerAlreadyApproved(msg.sender);

        transfer.approvals++;
        transfer.approved[msg.sender] = true;

        emit TransferApproved(transferId, msg.sender);
    }

    function executeTransfer(uint256 transferId) external onlyMultiSigner {
        Transfer storage transfer = transfers[transferId];
        if (transfer.approvals < quorum) revert QuorumNotReached(transferId);
        if (transfer.executed) revert TransferAlreadyExecuted(transferId);

        uint256 balance = address(this).balance;
        if (transfer.amount > balance) revert InsufficientBalance();

        (bool success,) = transfer.to.call{value: transfer.amount}("");
        if (!success) revert TransferFailed(transferId);

        transfer.executed = true;

        emit TransferExecuted(transferId);
    }

    /// @notice Get the details of a transfer
    /// @param transferId The ID of the transfer
    function getTransfer(uint256 transferId)
        external
        view
        returns (address to, uint256 amount, uint256 approvals, bool executed)
    {
        Transfer storage transfer = transfers[transferId];
        return (transfer.to, transfer.amount, transfer.approvals, transfer.executed);
    }

    /// @notice Check if a signer has approved a transfer
    /// @param transferId The ID of the transfer
    /// @param signer The address of the signer
    function hasSignedTransfer(uint256 transferId, address signer) external view returns (bool) {
        Transfer storage transfer = transfers[transferId];
        return transfer.approved[signer];
    }

    /// @notice Get the number of transfers
    function getTransferCount() external view returns (uint256) {
        return transfersCount;
    }
}
