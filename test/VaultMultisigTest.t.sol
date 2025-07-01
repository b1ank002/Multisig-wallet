// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {VaultMultisig} from "../src/VaultMultisig.sol";

contract VaultMultisigTest is Test {
    VaultMultisig vaultContract;

    uint256 quorum = 2;

    address account1 = vm.addr(1);
    address account2 = vm.addr(2);
    address account3 = vm.addr(3);
    address account4 = vm.addr(4);
    address account5 = vm.addr(5);
    address account6 = vm.addr(6);
    address account7 = vm.addr(7);

    address[] signers = [account1, account2, account3];
    address[] signers2 = [account4, account5, account6, account7];

    function setUp() public {
        vaultContract = new VaultMultisig(signers, quorum);
    }

    function test_constructor_Revert_SingersArrayCantBeEmpty(uint256 _quorum) public {
        vm.expectRevert(VaultMultisig.SingersArrayCantBeEmpty.selector);
        new VaultMultisig(new address[](0), _quorum);
    }

    function test_constructor_Revert_QuorumGreaterThanSigners(uint256 _quorum) public {
        vm.assume(_quorum > 1);

        vm.expectRevert(VaultMultisig.QuorumGreaterThanSigners.selector);
        new VaultMultisig(new address[](1), _quorum);
    }

    function test_constructor_Revert_SignerAlreadyExists() public {
        address[] memory sameSigners = new address[](2);
        sameSigners[0] = address(0x123);
        sameSigners[1] = address(0x123);

        vm.expectRevert(abi.encodeWithSelector(VaultMultisig.SignerAlreadyExists.selector, address(0x123)));
        new VaultMultisig(sameSigners, 1);
    }

    function test_constructor_Revert_InvalidMultisigSigner(uint256 _quorum) public {
        signers2.push(address(0));
        vm.assume(_quorum >= 1);
        vm.assume(_quorum < signers2.length);

        vm.expectRevert(VaultMultisig.InvalidMultisigSigner.selector);
        new VaultMultisig(signers2, _quorum);

        signers2.pop();
    }

    function test_constructor_Revert_QuorumLessThanOne() public {
        vm.expectRevert(VaultMultisig.QuorumLessThanOne.selector);
        new VaultMultisig(signers, 0);
    }

    function test_onlyMultiSigner_Revert_InvalidMultisigSigner(address _from, address _to, uint256 _amount) public {
        vm.assume(_from != account1);
        vm.assume(_from != account2);
        vm.assume(_from != account3);

        vm.expectRevert(VaultMultisig.InvalidMultisigSigner.selector);
        vm.prank(_from);
        vaultContract.InitializeTransfer(_to, _amount);
    }

    function test_updateSignersAndQuorum_Revert_QuorumLessThanOne() public {
        vm.expectRevert(VaultMultisig.QuorumLessThanOne.selector);
        vm.prank(account1);
        vaultContract.updateSignersAndQuorum(signers2, 0);
    }

    function test_updateSignersAndQuorum_Revert_QuorumGreaterThanSigners(uint256 _quorum) public {
        vm.assume(_quorum > signers2.length);

        vm.expectRevert(VaultMultisig.QuorumGreaterThanSigners.selector);
        vm.prank(account1);
        vaultContract.updateSignersAndQuorum(signers, _quorum);
    }

    function test_updateSignersAndQuorum_Revert_InvalidMultisigSigner(uint256 _quorum) public {
        signers2.push(address(0));
        vm.assume(_quorum >= 1);
        vm.assume(_quorum < signers2.length);

        vm.expectRevert(VaultMultisig.InvalidMultisigSigner.selector);
        vm.prank(account1);
        vaultContract.updateSignersAndQuorum(signers2, _quorum);

        signers2.pop();
    }

    function test_updateSignersAndQuorum_Revert_SingersArrayCantBeEmpty(uint256 _quorum) public {
        vm.assume(_quorum >= 1);
        vm.assume(_quorum < signers2.length);

        address[] memory emptyArr = new address[](0);

        vm.expectRevert(VaultMultisig.SingersArrayCantBeEmpty.selector);
        vm.prank(account1);
        vaultContract.updateSignersAndQuorum(emptyArr, _quorum);
    }

    function test_updateSignersAndQuorum_Revert_SignerAlreadyExists() public {
        address[] memory sameSigners = new address[](2);
        sameSigners[0] = address(0x123);
        sameSigners[1] = address(0x123);

        vm.expectRevert(abi.encodeWithSelector(VaultMultisig.SignerAlreadyExists.selector, address(0x123)));
        vm.prank(account1);
        vaultContract.updateSignersAndQuorum(sameSigners, 1);
    }

    function test_updateSignersAndQuorum_Success(uint256 _quorum) public {
        vm.assume(_quorum >= 1);
        vm.assume(_quorum < signers2.length);

        vm.expectEmit(true, false, false, true);
        emit VaultMultisig.MultiSigSignersUpdated();
        vm.expectEmit(true, false, false, true);
        emit VaultMultisig.QuorumUpdated(_quorum);
        vm.prank(account1);
        vaultContract.updateSignersAndQuorum(signers2, _quorum);

        assertEq(signers2[0], vaultContract.multiSigSignersArray(0));
        assertEq(signers2[1], vaultContract.multiSigSignersArray(1));
        assertEq(signers2[2], vaultContract.multiSigSignersArray(2));
        assertEq(_quorum, vaultContract.quorum());
    }

    function test_InitializeTransfer_Revert_InvalidAmount(address _to) public {
        vm.assume(_to != address(0));
        vm.expectRevert(VaultMultisig.InvalidAmount.selector);
        vm.prank(account1);
        vaultContract.InitializeTransfer(_to, 0);
    }

    function test_InitializeTransfer_Revert_InvalidReceipient(uint256 _amount) public {
        address receipient = address(0);
        vm.expectRevert(VaultMultisig.InvalidReceipient.selector);
        vm.prank(account1);
        vaultContract.InitializeTransfer(receipient, _amount);
    }

    function test_InitializeTransfer_Success(address _to, uint256 _amount) public {
        vm.assume(_to != address(0));
        vm.assume(_amount != 0);
        vm.startPrank(account1);

        vm.expectEmit(true, false, false, true);
        emit VaultMultisig.TransferInitialized(0, _to, _amount);

        vaultContract.InitializeTransfer(_to, _amount);

        vm.stopPrank();

        (address to, uint256 amount, uint256 approvals, bool executed) = vaultContract.getTransfer(0);
        console.log(to, amount, approvals, executed);

        assertEq(_to, to);
        assertEq(_amount, amount);
        assertEq(1, approvals);
        assertFalse(executed);
    }

    function test_approveTransfer_Revert_SignerAlreadyApproved(address _to, uint256 _amount) public {
        vm.assume(_to != address(0));
        vm.assume(_amount != 0);

        vm.startPrank(account1);
        vaultContract.InitializeTransfer(_to, _amount);

        vm.expectRevert(abi.encodeWithSelector(VaultMultisig.SignerAlreadyApproved.selector, account1));
        vaultContract.approveTransfer(0);

        vm.stopPrank();
    }

    function test_approveTransfer_Revert_TransferAlreadyExecuted(address _to, uint256 _amount) public {
        vm.assume(_to != address(0));
        vm.assume(_to.code.length == 0);
        vm.assume(_amount != 0);

        vm.prank(account1);
        vaultContract.InitializeTransfer(_to, _amount);

        vm.startPrank(account2);
        vaultContract.approveTransfer(0);

        vm.deal(address(vaultContract), _amount);
        vaultContract.executeTransfer(0);

        vm.expectRevert(abi.encodeWithSelector(VaultMultisig.TransferAlreadyExecuted.selector, 0));
        vaultContract.approveTransfer(0);

        vm.stopPrank();
    }

    function test_approveTransfer_Success(address _to, uint256 _amount) public {
        vm.assume(_to != address(0));
        vm.assume(_amount != 0);

        vm.prank(account1);
        vaultContract.InitializeTransfer(_to, _amount);

        vm.expectEmit(true, false, false, false);
        emit VaultMultisig.TransferApproved(0, account2);
        vm.prank(account2);
        vaultContract.approveTransfer(0);

        (address to, uint256 amount, uint256 approvals, bool executed) = vaultContract.getTransfer(0);
        console.log(to, amount, approvals, executed);

        assertEq(_to, to);
        assertEq(_amount, amount);
        assertEq(2, approvals);
        assertFalse(executed);
    }

    function test_executeTransfer_Revert_QuarumNotReached(address _to, uint256 _amount) public {
        vm.assume(_to != address(0));
        vm.assume(_amount != 0);

        vm.prank(account1);
        vaultContract.InitializeTransfer(_to, _amount);

        vm.expectRevert(abi.encodeWithSelector(VaultMultisig.QuorumNotReached.selector, 0));
        vm.prank(account2);
        vaultContract.executeTransfer(0);
    }

    function test_executeTransfer_Revert_TransferAlreadyExecuted(address _to, uint256 _amount) public {
        vm.assume(_to != address(0));
        vm.assume(_to.code.length == 0);
        vm.assume(_amount != 0);

        vm.prank(account1);
        vaultContract.InitializeTransfer(_to, _amount);

        vm.startPrank(account2);
        vaultContract.approveTransfer(0);

        vm.deal(address(vaultContract), _amount);
        vaultContract.executeTransfer(0);

        vm.expectRevert(abi.encodeWithSelector(VaultMultisig.TransferAlreadyExecuted.selector, 0));
        vaultContract.executeTransfer(0);

        vm.stopPrank();
    }

    function test_executeTransfer_Revert_InsufficientBalance(address _to, uint256 _amount) public {
        vm.assume(_to != address(0));
        vm.assume(_amount != 0);

        vm.prank(account1);
        vaultContract.InitializeTransfer(_to, _amount);

        vm.startPrank(account2);
        vaultContract.approveTransfer(0);

        vm.deal(address(vaultContract), _amount - 1 wei);

        vm.expectRevert(VaultMultisig.InsufficientBalance.selector);
        vaultContract.executeTransfer(0);

        vm.stopPrank();
    }

    function test_executeTransfer_Revert_TransferFailed(uint256 _amount) public {
        vm.assume(_amount != 0);

        NonPayableRecepient recepient = new NonPayableRecepient();

        vm.prank(account1);
        vaultContract.InitializeTransfer(address(recepient), _amount);

        vm.startPrank(account2);
        vaultContract.approveTransfer(0);

        vm.deal(address(vaultContract), _amount);

        vm.expectRevert(abi.encodeWithSelector(VaultMultisig.TransferFailed.selector, 0));
        vaultContract.executeTransfer(0);

        vm.stopPrank();
    }

    function test_executeTransfer_Success(address _to, uint256 _amount) public {
        vm.assume(_to != address(0));
        vm.assume(_to.code.length == 0);
        vm.assume(_amount != 0);

        vm.prank(account1);
        vaultContract.InitializeTransfer(_to, _amount);

        vm.startPrank(account2);
        vaultContract.approveTransfer(0);

        vm.deal(address(vaultContract), _amount);
        vm.expectEmit(true, false, false, true);
        emit VaultMultisig.TransferExecuted(0);
        vaultContract.executeTransfer(0);

        vm.stopPrank();

        (address to, uint256 amount, uint256 approvals, bool executed) = vaultContract.getTransfer(0);
        console.log(to, amount, approvals, executed);

        assertEq(_to, to);
        assertEq(_amount, amount);
        assertEq(2, approvals);
        assertTrue(executed);
    }

    function test_hasSignetTransfer_Success(address _to, uint256 _amount) public {
        vm.assume(_to != address(0));
        vm.assume(_amount != 0);

        vm.startPrank(account1);
        vaultContract.InitializeTransfer(_to, _amount);

        assertTrue(vaultContract.hasSignedTransfer(0, account1));
        assertFalse(vaultContract.hasSignedTransfer(0, account2));

        vm.stopPrank();

        vm.prank(account2);
        vaultContract.approveTransfer(0);

        assertTrue(vaultContract.hasSignedTransfer(0, account1));
        assertTrue(vaultContract.hasSignedTransfer(0, account2));
    }

    function test_getTransferCount_Success(address _to, uint256 _amount) public {
        vm.assume(_to != address(0));
        vm.assume(_amount != 0);

        uint256 countBefore = vaultContract.getTransferCount();
        assertEq(0, countBefore);

        vm.startPrank(account1);
        vaultContract.InitializeTransfer(_to, _amount);

        uint256 countAfter = vaultContract.getTransferCount();
        assertEq(1, countAfter);
    }
}

contract NonPayableRecepient {
    function foo() public pure returns (string memory) {
        return "Im non-payable";
    }
}
