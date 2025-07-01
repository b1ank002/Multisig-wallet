// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {VaultMultisigERC20} from "../src/VaultMultisigERC20.sol";
import {BlankERC20} from "../src/ERC20tokenForTest.sol";

contract VaultMultisigTest is Test {
    BlankERC20 token;

    VaultMultisigERC20 vaultContract;

    uint256 quorum = 2;

    address account1 = vm.addr(1);
    address account2 = vm.addr(2);
    address account3 = vm.addr(3);

    address[] signers = [account1, account2, account3];

    function setUp() public {
        token = new BlankERC20(address(this));

        vaultContract = new VaultMultisigERC20(address(token), signers, quorum);
    }

    function test_constructor_Revert_InvalidToken(uint256 _quorum) public {
        vm.expectRevert(VaultMultisigERC20.InvalidToken.selector);
        new VaultMultisigERC20(address(0), new address[](0), _quorum);
    }

    function test_constructor_Revert_SingersArrayCantBeEmpty(uint256 _quorum) public {
        vm.expectRevert(VaultMultisigERC20.SingersArrayCantBeEmpty.selector);
        new VaultMultisigERC20(address(token), new address[](0), _quorum);
    }

    function test_constructor_Revert_QuorumGreaterThanSigners(uint256 _quorum) public {
        vm.assume(_quorum > 1);

        vm.expectRevert(VaultMultisigERC20.QuorumGreaterThanSigners.selector);
        new VaultMultisigERC20(address(token), new address[](1), _quorum);
    }

    function test_constructor_Revert_QuorumLessThanOne() public {
        vm.expectRevert(VaultMultisigERC20.QuorumLessThanOne.selector);
        new VaultMultisigERC20(address(token), signers, 0);
    }

    function test_onlyMultiSigner_Revert_InvalidMultisigSigner(address _from, address _to, uint256 _amount) public {
        vm.assume(_from != account1);
        vm.assume(_from != account2);
        vm.assume(_from != account3);

        vm.expectRevert(abi.encodeWithSelector(VaultMultisigERC20.InvalidMultisigSigner.selector, _from));
        vm.prank(_from);
        vaultContract.initializeTransfer(_to, _amount);
    }

    function test_InitializeTransfer_Revert_InvalidAmount(address _to) public {
        vm.assume(_to != address(0));
        vm.expectRevert(VaultMultisigERC20.InvalidAmount.selector);
        vm.prank(account1);
        vaultContract.initializeTransfer(_to, 0);
    }

    function test_InitializeTransfer_Revert_InvalidReceipient(uint256 _amount) public {
        address receipient = address(0);
        vm.expectRevert(VaultMultisigERC20.InvalidReceipient.selector);
        vm.prank(account1);
        vaultContract.initializeTransfer(receipient, _amount);
    }

    function test_InitializeTransfer_Success(address _to, uint256 _amount) public {
        vm.assume(_to != address(0));
        vm.assume(_amount != 0);

        vm.expectEmit(true, false, false, true);
        emit VaultMultisigERC20.TransferInitialized(0, _to, _amount);

        vm.prank(account1);
        vaultContract.initializeTransfer(_to, _amount);

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
        vaultContract.initializeTransfer(_to, _amount);

        vm.expectRevert(abi.encodeWithSelector(VaultMultisigERC20.SignerAlreadyApproved.selector, account1));
        vaultContract.approveTransfer(0);

        vm.stopPrank();
    }

    function test_approveTransfer_Revert_TransferAlreadyExecuted(address _to, uint256 _amount) public {
        vm.assume(_amount != 0);
        vm.assume(_amount <= token.balanceOf(address(this)));
        vm.assume(_to != address(0));

        token.transfer(address(vaultContract), _amount);

        vm.prank(account1);
        vaultContract.initializeTransfer(_to, _amount);

        vm.startPrank(account2);
        vaultContract.approveTransfer(0);

        vaultContract.executeTransfer(0);

        vm.expectRevert(abi.encodeWithSelector(VaultMultisigERC20.TransferAlreadyExecuted.selector, 0));
        vaultContract.approveTransfer(0);

        vm.stopPrank();
    }

    function test_approveTransfer_Success(address _to, uint256 _amount) public {
        vm.assume(_to != address(0));
        vm.assume(_amount != 0);

        vm.prank(account1);
        vaultContract.initializeTransfer(_to, _amount);

        vm.expectEmit(true, false, false, false);
        emit VaultMultisigERC20.TransferApproved(0, account2);
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
        vaultContract.initializeTransfer(_to, _amount);

        vm.expectRevert(abi.encodeWithSelector(VaultMultisigERC20.QuorumNotReached.selector, 0));
        vm.prank(account2);
        vaultContract.executeTransfer(0);
    }

    function test_executeTransfer_Revert_TransferAlreadyExecuted(address _to, uint256 _amount) public {
        vm.assume(_amount != 0);
        vm.assume(_amount <= token.balanceOf(address(this)));
        vm.assume(_to != address(0));

        token.transfer(address(vaultContract), _amount);

        vm.prank(account1);
        vaultContract.initializeTransfer(_to, _amount);

        vm.startPrank(account2);
        vaultContract.approveTransfer(0);

        vaultContract.executeTransfer(0);

        vm.expectRevert(abi.encodeWithSelector(VaultMultisigERC20.TransferAlreadyExecuted.selector, 0));
        vaultContract.executeTransfer(0);

        vm.stopPrank();
    }

    function test_executeTransfer_Revert_InsufficientBalance(address _to, uint256 _amount) public {
        vm.assume(_amount != 0);
        vm.assume(_amount <= token.balanceOf(address(this)));
        vm.assume(_to != address(0));

        token.transfer(address(vaultContract), _amount - 1);

        vm.prank(account1);
        vaultContract.initializeTransfer(_to, _amount);

        vm.startPrank(account2);
        vaultContract.approveTransfer(0);

        vm.expectRevert(VaultMultisigERC20.InsufficientBalance.selector);
        vaultContract.executeTransfer(0);

        vm.stopPrank();
    }

    function test_executeTransfer_Revert_TransferFailed(address _to, uint256 _amount) public {
        vm.assume(_to != address(0));
        vm.assume(_amount != 0);
        vm.assume(_amount <= token.balanceOf(address(this)));

        token.transfer(address(vaultContract), _amount);
        token.pause();

        vm.prank(account1);
        vaultContract.initializeTransfer(_to, _amount);

        vm.startPrank(account2);
        vaultContract.approveTransfer(0);

        vm.expectRevert(abi.encodeWithSelector(VaultMultisigERC20.TransferFailed.selector, 0));
        vaultContract.executeTransfer(0);

        vm.stopPrank();
    }

    function test_executeTransfer_Success(address _to, uint256 _amount) public {
        vm.assume(_amount != 0);
        vm.assume(_amount <= token.balanceOf(address(this)));
        vm.assume(_to != address(0));

        token.transfer(address(vaultContract), _amount);

        vm.prank(account1);
        vaultContract.initializeTransfer(_to, _amount);

        vm.startPrank(account2);
        vaultContract.approveTransfer(0);

        vm.expectEmit(true, false, false, true);
        emit VaultMultisigERC20.TransferExecuted(0);
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
        vaultContract.initializeTransfer(_to, _amount);

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
        vaultContract.initializeTransfer(_to, _amount);

        uint256 countAfter = vaultContract.getTransferCount();
        assertEq(1, countAfter);
    }
}
