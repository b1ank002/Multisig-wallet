// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract VaultMultisigERC20 {
    /// @notice Token contract
    IERC20 public token;

    /// @notice The number of signatures required to execute a transaction
    uint256 public quorum;

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

    /// @notice Checks if  the token address is valid
    error InvalidToken();

    /// @notice Cheks if the array of signers is not empty
    error SingersArrayCantBeEmpty();

    /// @notice Checks if the quorum is less than the number of signers
    error QuorumGreaterThanSigners();

    /// @notice Checks if the quorum is more than one
    error QuorumLessThanOne();

    /// @notice Checks if signer is multisig signer
    /// @param signer The address of the signer
    error InvalidMultisigSigner(address signer);

    /// @notice Checks if the recipient is valid
    error InvalidReceipient();

    /// @notice Checks if the amount is valid
    error InvalidAmount();

    /// @notice Checks if the transfer is not executed
    /// @param transferId The ID of the transfer
    error TransferAlreadyExecuted(uint256 transferId);

    /// @notice Checks if the signer has not approved the transfer
    /// @param signer The address of the signer
    error SignerAlreadyApproved(address signer);

    /// @notice Checks if the quorum is reached
    /// @param transferId The ID of the transfer
    error QuorumNotReached(uint256 transferId);

    /// @notice Checks if the transfer is succeed
    /// @param transferId The ID of the transfer
    error TransferFailed(uint256 transferId);

    /// @notice Checks if the balance is enough
    error InsufficientBalance();

    /// @notice The event is emitted when a transfer is initialized
    /// @param transferId The ID of the transfer
    /// @param to The address of the recipient
    /// @param amount The amount of tokens to transfer
    event TransferInitialized(uint256 indexed transferId, address to, uint256 amount);

    /// @notice The event is emitted when the signer approves the transfer
    /// @param transferId The ID of the transfer
    /// @param signer The address of the signer
    event TransferApproved(uint256 indexed transferId, address signer);

    /// @notice The event is emitted when a transfer is executed
    /// @param transferId The ID of the transfer
    event TransferExecuted(uint256 indexed transferId);

    /// @notice Initialize the multisig ERC20 contract
    /// @param _token The address of the token contract
    /// @param _signers The array of multisig signers
    /// @param _quorum The number of signatures required to execute a transaction
    constructor(address _token, address[] memory _signers, uint256 _quorum) {
        if (_token == address(0)) revert InvalidToken();
        if (_signers.length == 0) revert SingersArrayCantBeEmpty();
        if (_quorum > _signers.length) revert QuorumGreaterThanSigners();
        if (_quorum == 0) revert QuorumLessThanOne();

        for (uint256 i = 0; i < _signers.length;) {
            multiSigSigners[_signers[i]] = true;

            unchecked {
                ++i;
            }
        }

        token = IERC20(_token);
        quorum = _quorum;
    }

    /// @notice The modifier is used to check if the signer is a multisig signer
    modifier onlyMultiSigner() {
        if (!multiSigSigners[msg.sender]) revert InvalidMultisigSigner(msg.sender);
        _;
    }

    /// @notice Initialize a transfer
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to transfer
    function initializeTransfer(address _to, uint256 _amount) external onlyMultiSigner {
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
    function approveTransfer(uint256 transferId) external onlyMultiSigner {
        Transfer storage transfer = transfers[transferId];
        if (transfer.executed) revert TransferAlreadyExecuted(transferId);
        if (transfer.approved[msg.sender]) revert SignerAlreadyApproved(msg.sender);

        transfer.approvals++;
        transfer.approved[msg.sender] = true;

        emit TransferApproved(transferId, msg.sender);
    }

    /// @notice Execute a transfer
    /// @param transferId The ID of the transfer
    /// @dev The tokens MUST be on the contract
    function executeTransfer(uint256 transferId) external onlyMultiSigner {
        Transfer storage transfer = transfers[transferId];
        if (transfer.approvals < quorum) revert QuorumNotReached(transferId);
        if (transfer.executed) revert TransferAlreadyExecuted(transferId);

        uint256 balance = token.balanceOf(address(this));
        if (transfer.amount > balance) revert InsufficientBalance();
        require(token.transfer(transfer.to, transfer.amount), TransferFailed(transferId));

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
