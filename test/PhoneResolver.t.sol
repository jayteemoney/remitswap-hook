// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { PhoneNumberResolver } from "../src/compliance/PhoneNumberResolver.sol";

/// @title PhoneResolverTest
/// @notice Tests for the PhoneNumberResolver contract
contract PhoneResolverTest is Test {
    PhoneNumberResolver internal resolver;

    address internal owner;
    address internal alice;
    address internal bob;
    address internal charlie;

    // Test phone numbers
    string internal constant KENYA_PHONE = "+254712345678";
    string internal constant NIGERIA_PHONE = "+2348061234567";
    string internal constant USA_PHONE = "+14155551234";
    string internal constant UK_PHONE = "+447911123456";

    bytes32 internal kenyaHash;
    bytes32 internal nigeriaHash;
    bytes32 internal usaHash;
    bytes32 internal ukHash;

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        resolver = new PhoneNumberResolver();

        // Compute phone hashes
        kenyaHash = keccak256(abi.encodePacked(KENYA_PHONE));
        nigeriaHash = keccak256(abi.encodePacked(NIGERIA_PHONE));
        usaHash = keccak256(abi.encodePacked(USA_PHONE));
        ukHash = keccak256(abi.encodePacked(UK_PHONE));
    }

    // ============ Setup Tests ============

    function test_Deployment() public view {
        assertEq(resolver.owner(), owner);
    }

    // ============ Phone Hash Tests ============

    function test_ComputePhoneHash() public view {
        bytes32 computed = resolver.computePhoneHash(KENYA_PHONE);
        assertEq(computed, kenyaHash);
    }

    function test_ComputePhoneHash_DifferentPhones() public view {
        bytes32 kenya = resolver.computePhoneHash(KENYA_PHONE);
        bytes32 nigeria = resolver.computePhoneHash(NIGERIA_PHONE);

        assertTrue(kenya != nigeria);
    }

    // ============ Registration Tests ============

    function test_RegisterPhone_Success() public {
        resolver.registerPhone(kenyaHash, alice);

        assertEq(resolver.phoneToAddress(kenyaHash), alice);
        assertEq(resolver.addressToPhone(alice), kenyaHash);
        assertTrue(resolver.isRegistered(kenyaHash));
        assertTrue(resolver.hasPhone(alice));
    }

    function test_RegisterPhone_EmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit PhoneNumberResolver.PhoneRegistered(kenyaHash, alice);

        resolver.registerPhone(kenyaHash, alice);
    }

    function test_RegisterPhone_RevertIfZeroAddress() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidWallet()"));
        resolver.registerPhone(kenyaHash, address(0));
    }

    function test_RegisterPhone_RevertIfAlreadyRegistered() public {
        resolver.registerPhone(kenyaHash, alice);

        vm.expectRevert(abi.encodeWithSignature("PhoneAlreadyRegistered()"));
        resolver.registerPhone(kenyaHash, bob);
    }

    function test_RegisterPhone_RevertIfWalletHasPhone() public {
        resolver.registerPhone(kenyaHash, alice);

        vm.expectRevert(abi.encodeWithSignature("WalletAlreadyHasPhone()"));
        resolver.registerPhone(nigeriaHash, alice);
    }

    function test_RegisterPhone_RevertIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        resolver.registerPhone(kenyaHash, alice);
    }

    // ============ String Registration Tests ============

    function test_RegisterPhoneString_Success() public {
        resolver.registerPhoneString(KENYA_PHONE, alice);

        assertEq(resolver.resolve(kenyaHash), alice);
        assertTrue(resolver.isRegistered(kenyaHash));
    }

    function test_RegisterPhoneString_RevertIfAlreadyRegistered() public {
        resolver.registerPhoneString(KENYA_PHONE, alice);

        vm.expectRevert(abi.encodeWithSignature("PhoneAlreadyRegistered()"));
        resolver.registerPhoneString(KENYA_PHONE, bob);
    }

    // ============ Batch Registration Tests ============

    function test_BatchRegister_Success() public {
        bytes32[] memory hashes = new bytes32[](3);
        hashes[0] = kenyaHash;
        hashes[1] = nigeriaHash;
        hashes[2] = usaHash;

        address[] memory wallets = new address[](3);
        wallets[0] = alice;
        wallets[1] = bob;
        wallets[2] = charlie;

        resolver.batchRegister(hashes, wallets);

        assertEq(resolver.resolve(kenyaHash), alice);
        assertEq(resolver.resolve(nigeriaHash), bob);
        assertEq(resolver.resolve(usaHash), charlie);
    }

    function test_BatchRegister_SkipsInvalidEntries() public {
        bytes32[] memory hashes = new bytes32[](3);
        hashes[0] = kenyaHash;
        hashes[1] = nigeriaHash;
        hashes[2] = usaHash;

        address[] memory wallets = new address[](3);
        wallets[0] = alice;
        wallets[1] = address(0); // Invalid - should be skipped
        wallets[2] = charlie;

        resolver.batchRegister(hashes, wallets);

        assertEq(resolver.resolve(kenyaHash), alice);
        assertEq(resolver.resolve(nigeriaHash), address(0)); // Not registered
        assertEq(resolver.resolve(usaHash), charlie);
    }

    function test_BatchRegister_SkipsDuplicates() public {
        resolver.registerPhone(kenyaHash, alice);

        bytes32[] memory hashes = new bytes32[](2);
        hashes[0] = kenyaHash; // Already registered
        hashes[1] = nigeriaHash;

        address[] memory wallets = new address[](2);
        wallets[0] = bob; // Won't override alice
        wallets[1] = bob;

        resolver.batchRegister(hashes, wallets);

        // Kenya should still be alice
        assertEq(resolver.resolve(kenyaHash), alice);
        assertEq(resolver.resolve(nigeriaHash), bob);
    }

    function test_BatchRegister_RevertIfLengthMismatch() public {
        bytes32[] memory hashes = new bytes32[](2);
        address[] memory wallets = new address[](3);

        vm.expectRevert(abi.encodeWithSignature("LengthMismatch()"));
        resolver.batchRegister(hashes, wallets);
    }

    // ============ Unregistration Tests ============

    function test_UnregisterPhone_Success() public {
        resolver.registerPhone(kenyaHash, alice);
        resolver.unregisterPhone(kenyaHash);

        assertEq(resolver.resolve(kenyaHash), address(0));
        assertEq(resolver.addressToPhone(alice), bytes32(0));
        assertFalse(resolver.isRegistered(kenyaHash));
        assertFalse(resolver.hasPhone(alice));
    }

    function test_UnregisterPhone_EmitsEvent() public {
        resolver.registerPhone(kenyaHash, alice);

        vm.expectEmit(true, true, false, true);
        emit PhoneNumberResolver.PhoneUnregistered(kenyaHash, alice);

        resolver.unregisterPhone(kenyaHash);
    }

    function test_UnregisterPhone_RevertIfNotRegistered() public {
        vm.expectRevert(abi.encodeWithSignature("PhoneNotRegistered()"));
        resolver.unregisterPhone(kenyaHash);
    }

    // ============ Update Tests ============

    function test_UpdatePhoneWallet_Success() public {
        resolver.registerPhone(kenyaHash, alice);
        resolver.updatePhoneWallet(kenyaHash, bob);

        assertEq(resolver.resolve(kenyaHash), bob);
        assertEq(resolver.addressToPhone(bob), kenyaHash);
        assertEq(resolver.addressToPhone(alice), bytes32(0));
        assertFalse(resolver.hasPhone(alice));
        assertTrue(resolver.hasPhone(bob));
    }

    function test_UpdatePhoneWallet_EmitsEvent() public {
        resolver.registerPhone(kenyaHash, alice);

        vm.expectEmit(true, true, true, true);
        emit PhoneNumberResolver.PhoneUpdated(kenyaHash, alice, bob);

        resolver.updatePhoneWallet(kenyaHash, bob);
    }

    function test_UpdatePhoneWallet_RevertIfNotRegistered() public {
        vm.expectRevert(abi.encodeWithSignature("PhoneNotRegistered()"));
        resolver.updatePhoneWallet(kenyaHash, bob);
    }

    function test_UpdatePhoneWallet_RevertIfZeroAddress() public {
        resolver.registerPhone(kenyaHash, alice);

        vm.expectRevert(abi.encodeWithSignature("InvalidWallet()"));
        resolver.updatePhoneWallet(kenyaHash, address(0));
    }

    function test_UpdatePhoneWallet_RevertIfNewWalletHasPhone() public {
        resolver.registerPhone(kenyaHash, alice);
        resolver.registerPhone(nigeriaHash, bob);

        vm.expectRevert(abi.encodeWithSignature("WalletAlreadyHasPhone()"));
        resolver.updatePhoneWallet(kenyaHash, bob);
    }

    // ============ Resolution Tests ============

    function test_Resolve_ReturnsCorrectAddress() public {
        resolver.registerPhone(kenyaHash, alice);

        assertEq(resolver.resolve(kenyaHash), alice);
    }

    function test_Resolve_ReturnsZeroIfNotRegistered() public view {
        assertEq(resolver.resolve(kenyaHash), address(0));
    }

    function test_ResolveString_Success() public {
        resolver.registerPhoneString(KENYA_PHONE, alice);

        assertEq(resolver.resolveString(KENYA_PHONE), alice);
    }

    // ============ View Functions Tests ============

    function test_IsRegistered() public {
        assertFalse(resolver.isRegistered(kenyaHash));

        resolver.registerPhone(kenyaHash, alice);

        assertTrue(resolver.isRegistered(kenyaHash));
    }

    function test_HasPhone() public {
        assertFalse(resolver.hasPhone(alice));

        resolver.registerPhone(kenyaHash, alice);

        assertTrue(resolver.hasPhone(alice));
    }

    function test_GetPhoneHash() public {
        resolver.registerPhone(kenyaHash, alice);

        assertEq(resolver.getPhoneHash(alice), kenyaHash);
    }

    function test_GetPhoneHash_ReturnsZeroIfNoPhone() public view {
        assertEq(resolver.getPhoneHash(alice), bytes32(0));
    }

    // ============ Re-registration After Unregister Tests ============

    function test_CanReregisterAfterUnregister() public {
        resolver.registerPhone(kenyaHash, alice);
        resolver.unregisterPhone(kenyaHash);

        // Should be able to register same phone to different wallet
        resolver.registerPhone(kenyaHash, bob);
        assertEq(resolver.resolve(kenyaHash), bob);
    }

    function test_CanRegisterSameWalletAfterUnregister() public {
        resolver.registerPhone(kenyaHash, alice);
        resolver.unregisterPhone(kenyaHash);

        // Should be able to register different phone to same wallet
        resolver.registerPhone(nigeriaHash, alice);
        assertEq(resolver.resolve(nigeriaHash), alice);
    }

    // ============ Fuzz Tests ============

    function testFuzz_RegisterAndResolve(bytes32 phoneHash, address wallet) public {
        vm.assume(wallet != address(0));
        vm.assume(phoneHash != bytes32(0));

        resolver.registerPhone(phoneHash, wallet);

        assertEq(resolver.resolve(phoneHash), wallet);
        assertEq(resolver.getPhoneHash(wallet), phoneHash);
        assertTrue(resolver.isRegistered(phoneHash));
        assertTrue(resolver.hasPhone(wallet));
    }

    function testFuzz_UnregisterClearsAll(bytes32 phoneHash, address wallet) public {
        vm.assume(wallet != address(0));
        vm.assume(phoneHash != bytes32(0));

        resolver.registerPhone(phoneHash, wallet);
        resolver.unregisterPhone(phoneHash);

        assertEq(resolver.resolve(phoneHash), address(0));
        assertEq(resolver.getPhoneHash(wallet), bytes32(0));
        assertFalse(resolver.isRegistered(phoneHash));
        assertFalse(resolver.hasPhone(wallet));
    }
}
