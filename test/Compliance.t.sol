// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { AllowlistCompliance } from "../src/compliance/AllowlistCompliance.sol";

/// @title ComplianceTest
/// @notice Tests for the AllowlistCompliance contract
contract ComplianceTest is Test {
    AllowlistCompliance internal compliance;

    address internal owner;
    address internal hook;
    address internal alice;
    address internal bob;
    address internal charlie;
    address internal blocked;

    uint256 internal constant DEFAULT_LIMIT = 10_000 * 1e6;
    uint256 internal constant CUSTOM_LIMIT = 50_000 * 1e6;
    uint256 internal constant MIN_AMOUNT = 1e6;

    function setUp() public {
        owner = address(this);
        hook = makeAddr("hook");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        blocked = makeAddr("blocked");

        compliance = new AllowlistCompliance();
        compliance.setHook(hook);
    }

    // ============ Setup Tests ============

    function test_Deployment() public view {
        assertEq(compliance.owner(), owner);
        assertEq(compliance.hook(), hook);
        assertEq(compliance.defaultDailyLimit(), DEFAULT_LIMIT);
        assertEq(compliance.minimumAmount(), MIN_AMOUNT);
    }

    // ============ Allowlist Tests ============

    function test_AddToAllowlist_Success() public {
        compliance.addToAllowlist(alice, 0);

        assertTrue(compliance.allowlist(alice));
        assertTrue(compliance.isOnAllowlist(alice));
    }

    function test_AddToAllowlist_WithCustomLimit() public {
        compliance.addToAllowlist(alice, CUSTOM_LIMIT);

        assertTrue(compliance.allowlist(alice));
        assertEq(compliance.getDailyLimit(alice), CUSTOM_LIMIT);
    }

    function test_AddToAllowlist_RevertIfZeroAddress() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidAddress()"));
        compliance.addToAllowlist(address(0), 0);
    }

    function test_AddToAllowlist_RevertIfAlreadyOnList() public {
        compliance.addToAllowlist(alice, 0);

        vm.expectRevert(abi.encodeWithSignature("AlreadyOnAllowlist()"));
        compliance.addToAllowlist(alice, 0);
    }

    function test_AddToAllowlist_RevertIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        compliance.addToAllowlist(bob, 0);
    }

    function test_BatchAddToAllowlist_Success() public {
        address[] memory accounts = new address[](3);
        accounts[0] = alice;
        accounts[1] = bob;
        accounts[2] = charlie;

        uint256[] memory limits = new uint256[](3);
        limits[0] = 0;
        limits[1] = CUSTOM_LIMIT;
        limits[2] = 0;

        compliance.batchAddToAllowlist(accounts, limits);

        assertTrue(compliance.allowlist(alice));
        assertTrue(compliance.allowlist(bob));
        assertTrue(compliance.allowlist(charlie));
        assertEq(compliance.getDailyLimit(bob), CUSTOM_LIMIT);
    }

    function test_BatchAddToAllowlist_RevertIfLengthMismatch() public {
        address[] memory accounts = new address[](2);
        accounts[0] = alice;
        accounts[1] = bob;

        uint256[] memory limits = new uint256[](3);

        vm.expectRevert(abi.encodeWithSignature("InvalidAmount()"));
        compliance.batchAddToAllowlist(accounts, limits);
    }

    function test_RemoveFromAllowlist_Success() public {
        compliance.addToAllowlist(alice, CUSTOM_LIMIT);
        compliance.removeFromAllowlist(alice);

        assertFalse(compliance.allowlist(alice));
        assertEq(compliance.customDailyLimits(alice), 0);
    }

    function test_RemoveFromAllowlist_RevertIfNotOnList() public {
        vm.expectRevert(abi.encodeWithSignature("NotOnAllowlist()"));
        compliance.removeFromAllowlist(alice);
    }

    // ============ Blocklist Tests ============

    function test_AddToBlocklist_Success() public {
        compliance.addToBlocklist(blocked);

        assertTrue(compliance.blocklist(blocked));
        assertTrue(compliance.isBlocked(blocked));
    }

    function test_AddToBlocklist_RevertIfZeroAddress() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidAddress()"));
        compliance.addToBlocklist(address(0));
    }

    function test_AddToBlocklist_RevertIfAlreadyBlocked() public {
        compliance.addToBlocklist(blocked);

        vm.expectRevert(abi.encodeWithSignature("AlreadyBlocked()"));
        compliance.addToBlocklist(blocked);
    }

    function test_RemoveFromBlocklist_Success() public {
        compliance.addToBlocklist(blocked);
        compliance.removeFromBlocklist(blocked);

        assertFalse(compliance.blocklist(blocked));
        assertFalse(compliance.isBlocked(blocked));
    }

    function test_RemoveFromBlocklist_RevertIfNotBlocked() public {
        vm.expectRevert(abi.encodeWithSignature("NotBlocked()"));
        compliance.removeFromBlocklist(alice);
    }

    // ============ Compliance Check Tests ============

    function test_IsCompliant_Success() public {
        compliance.addToAllowlist(alice, 0);

        bool compliant = compliance.isCompliant(alice, bob, 1000 * 1e6);
        assertTrue(compliant);
    }

    function test_IsCompliant_FailIfSenderBlocked() public {
        compliance.addToAllowlist(alice, 0);
        compliance.addToBlocklist(alice);

        bool compliant = compliance.isCompliant(alice, bob, 1000 * 1e6);
        assertFalse(compliant);
    }

    function test_IsCompliant_FailIfRecipientBlocked() public {
        compliance.addToAllowlist(alice, 0);
        compliance.addToBlocklist(bob);

        bool compliant = compliance.isCompliant(alice, bob, 1000 * 1e6);
        assertFalse(compliant);
    }

    function test_IsCompliant_FailIfNotOnAllowlist() public {
        bool compliant = compliance.isCompliant(alice, bob, 1000 * 1e6);
        assertFalse(compliant);
    }

    function test_IsCompliant_FailIfBelowMinimum() public {
        compliance.addToAllowlist(alice, 0);

        bool compliant = compliance.isCompliant(alice, bob, MIN_AMOUNT - 1);
        assertFalse(compliant);
    }

    function test_IsCompliant_FailIfExceedsDailyLimit() public {
        compliance.addToAllowlist(alice, 0);

        bool compliant = compliance.isCompliant(alice, bob, DEFAULT_LIMIT + 1);
        assertFalse(compliant);
    }

    function test_IsCompliant_WithCustomLimit() public {
        compliance.addToAllowlist(alice, CUSTOM_LIMIT);

        // Should pass with amount > default but < custom
        bool compliant = compliance.isCompliant(alice, bob, DEFAULT_LIMIT + 1000 * 1e6);
        assertTrue(compliant);

        // Should fail with amount > custom
        bool notCompliant = compliance.isCompliant(alice, bob, CUSTOM_LIMIT + 1);
        assertFalse(notCompliant);
    }

    // ============ Daily Limit Tests ============

    function test_DailyLimitTracking() public {
        compliance.addToAllowlist(alice, 0);

        // Record some usage
        vm.prank(hook);
        compliance.recordUsage(alice, 5000 * 1e6);

        // Check compliance for remaining amount
        assertTrue(compliance.isCompliant(alice, bob, 5000 * 1e6));

        // Should fail if exceeds remaining
        assertFalse(compliance.isCompliant(alice, bob, 5001 * 1e6));
    }

    function test_DailyLimitResetsNextDay() public {
        compliance.addToAllowlist(alice, 0);

        // Use up entire limit
        vm.prank(hook);
        compliance.recordUsage(alice, DEFAULT_LIMIT);

        assertFalse(compliance.isCompliant(alice, bob, MIN_AMOUNT));

        // Warp to next day
        vm.warp(block.timestamp + 1 days);

        assertTrue(compliance.isCompliant(alice, bob, MIN_AMOUNT));
    }

    function test_RecordUsage_RevertIfNotHook() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized()"));
        compliance.recordUsage(alice, 1000 * 1e6);
    }

    function test_GetRemainingDailyLimit() public {
        compliance.addToAllowlist(alice, 0);

        assertEq(compliance.getRemainingDailyLimit(alice), DEFAULT_LIMIT);

        vm.prank(hook);
        compliance.recordUsage(alice, 3000 * 1e6);

        assertEq(compliance.getRemainingDailyLimit(alice), DEFAULT_LIMIT - 3000 * 1e6);
    }

    function test_GetRemainingDailyLimit_ReturnsZeroWhenExceeded() public {
        compliance.addToAllowlist(alice, 0);

        vm.prank(hook);
        compliance.recordUsage(alice, DEFAULT_LIMIT);

        assertEq(compliance.getRemainingDailyLimit(alice), 0);
    }

    // ============ Admin Functions Tests ============

    function test_SetHook() public {
        address newHook = makeAddr("newHook");
        compliance.setHook(newHook);
        assertEq(compliance.hook(), newHook);
    }

    function test_SetHook_RevertIfZeroAddress() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidAddress()"));
        compliance.setHook(address(0));
    }

    function test_UpdateDailyLimit() public {
        compliance.addToAllowlist(alice, 0);
        compliance.updateDailyLimit(alice, CUSTOM_LIMIT);

        assertEq(compliance.getDailyLimit(alice), CUSTOM_LIMIT);
    }

    function test_SetDefaultDailyLimit() public {
        uint256 newLimit = 20_000 * 1e6;
        compliance.setDefaultDailyLimit(newLimit);

        assertEq(compliance.defaultDailyLimit(), newLimit);
    }

    function test_SetDefaultDailyLimit_RevertIfZero() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidAmount()"));
        compliance.setDefaultDailyLimit(0);
    }

    function test_SetMinimumAmount() public {
        uint256 newMinimum = 10 * 1e6;
        compliance.setMinimumAmount(newMinimum);

        assertEq(compliance.minimumAmount(), newMinimum);
    }

    // ============ View Functions Tests ============

    function test_GetComplianceStatus() public {
        compliance.addToAllowlist(alice, CUSTOM_LIMIT);

        vm.prank(hook);
        compliance.recordUsage(alice, 1000 * 1e6);

        (bool isAllowed, uint256 dailyUsed, uint256 dailyLimit) = compliance.getComplianceStatus(alice);

        assertTrue(isAllowed);
        assertEq(dailyUsed, 1000 * 1e6);
        assertEq(dailyLimit, CUSTOM_LIMIT);
    }

    function test_GetComplianceStatus_NotAllowedIfBlocked() public {
        compliance.addToAllowlist(alice, 0);
        compliance.addToBlocklist(alice);

        (bool isAllowed,,) = compliance.getComplianceStatus(alice);

        assertFalse(isAllowed);
    }

    // ============ Fuzz Tests ============

    function testFuzz_DailyLimit(uint256 usage, uint256 newTransfer) public {
        usage = bound(usage, 0, DEFAULT_LIMIT);
        newTransfer = bound(newTransfer, MIN_AMOUNT, DEFAULT_LIMIT);

        compliance.addToAllowlist(alice, 0);

        vm.prank(hook);
        compliance.recordUsage(alice, usage);

        bool shouldBeCompliant = (usage + newTransfer) <= DEFAULT_LIMIT;
        bool isCompliant = compliance.isCompliant(alice, bob, newTransfer);

        assertEq(isCompliant, shouldBeCompliant);
    }

    function testFuzz_CustomLimit(uint256 customLimit, uint256 amount) public {
        customLimit = bound(customLimit, MIN_AMOUNT, 1_000_000 * 1e6);
        amount = bound(amount, MIN_AMOUNT, customLimit);

        compliance.addToAllowlist(alice, customLimit);

        assertTrue(compliance.isCompliant(alice, bob, amount));
    }
}
