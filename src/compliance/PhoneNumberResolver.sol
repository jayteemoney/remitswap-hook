// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IPhoneNumberResolver } from "../interfaces/IPhoneNumberResolver.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title PhoneNumberResolver
/// @notice Resolves phone numbers to wallet addresses for remittances
/// @dev Uses a simple mapping for demo; production would integrate with Celo SocialConnect
/// @author dev_jaytee
contract PhoneNumberResolver is IPhoneNumberResolver, Ownable {
    // ============ State Variables ============

    /// @notice Mapping of phone number hash to wallet address
    /// @dev Phone numbers are hashed for privacy: keccak256(abi.encodePacked(phoneNumber))
    mapping(bytes32 => address) public phoneToAddress;

    /// @notice Mapping of address to phone hash (reverse lookup)
    mapping(address => bytes32) public addressToPhone;

    /// @notice Check if a phone number is registered
    mapping(bytes32 => bool) private _isRegistered;

    // ============ Events ============

    event PhoneRegistered(bytes32 indexed phoneHash, address indexed wallet);
    event PhoneUnregistered(bytes32 indexed phoneHash, address indexed wallet);
    event PhoneUpdated(bytes32 indexed phoneHash, address indexed oldWallet, address indexed newWallet);

    // ============ Errors ============

    error InvalidWallet();
    error PhoneAlreadyRegistered();
    error PhoneNotRegistered();
    error WalletAlreadyHasPhone();
    error LengthMismatch();

    // ============ Constructor ============

    constructor() Ownable(msg.sender) { }

    // ============ Admin Functions ============

    /// @notice Register a phone number to a wallet address
    /// @param phoneHash The keccak256 hash of the phone number (e.g., "+254712345678")
    /// @param wallet The wallet address to associate
    function registerPhone(bytes32 phoneHash, address wallet) external onlyOwner {
        if (wallet == address(0)) revert InvalidWallet();
        if (_isRegistered[phoneHash]) revert PhoneAlreadyRegistered();
        if (addressToPhone[wallet] != bytes32(0)) revert WalletAlreadyHasPhone();

        phoneToAddress[phoneHash] = wallet;
        addressToPhone[wallet] = phoneHash;
        _isRegistered[phoneHash] = true;

        emit PhoneRegistered(phoneHash, wallet);
    }

    /// @notice Batch register multiple phone numbers (for demo setup)
    /// @param phoneHashes Array of phone number hashes
    /// @param wallets Array of wallet addresses
    function batchRegister(bytes32[] calldata phoneHashes, address[] calldata wallets) external onlyOwner {
        if (phoneHashes.length != wallets.length) revert LengthMismatch();

        for (uint256 i = 0; i < phoneHashes.length; i++) {
            // Skip invalid entries silently
            if (wallets[i] == address(0)) continue;
            if (_isRegistered[phoneHashes[i]]) continue;
            if (addressToPhone[wallets[i]] != bytes32(0)) continue;

            phoneToAddress[phoneHashes[i]] = wallets[i];
            addressToPhone[wallets[i]] = phoneHashes[i];
            _isRegistered[phoneHashes[i]] = true;

            emit PhoneRegistered(phoneHashes[i], wallets[i]);
        }
    }

    /// @notice Unregister a phone number
    /// @param phoneHash The phone number hash to unregister
    function unregisterPhone(bytes32 phoneHash) external onlyOwner {
        if (!_isRegistered[phoneHash]) revert PhoneNotRegistered();

        address wallet = phoneToAddress[phoneHash];
        delete phoneToAddress[phoneHash];
        delete addressToPhone[wallet];
        _isRegistered[phoneHash] = false;

        emit PhoneUnregistered(phoneHash, wallet);
    }

    /// @notice Update wallet for an existing phone registration
    /// @param phoneHash The phone number hash
    /// @param newWallet The new wallet address
    function updatePhoneWallet(bytes32 phoneHash, address newWallet) external onlyOwner {
        if (!_isRegistered[phoneHash]) revert PhoneNotRegistered();
        if (newWallet == address(0)) revert InvalidWallet();
        if (addressToPhone[newWallet] != bytes32(0)) revert WalletAlreadyHasPhone();

        address oldWallet = phoneToAddress[phoneHash];

        // Clear old mapping
        delete addressToPhone[oldWallet];

        // Set new mappings
        phoneToAddress[phoneHash] = newWallet;
        addressToPhone[newWallet] = phoneHash;

        emit PhoneUpdated(phoneHash, oldWallet, newWallet);
    }

    // ============ IPhoneNumberResolver Implementation ============

    /// @inheritdoc IPhoneNumberResolver
    function resolve(bytes32 phoneHash) external view override returns (address wallet) {
        return phoneToAddress[phoneHash];
    }

    /// @inheritdoc IPhoneNumberResolver
    function computePhoneHash(string calldata phoneNumber) external pure override returns (bytes32) {
        return keccak256(abi.encodePacked(phoneNumber));
    }

    /// @inheritdoc IPhoneNumberResolver
    function isRegistered(bytes32 phoneHash) external view override returns (bool) {
        return _isRegistered[phoneHash];
    }

    /// @inheritdoc IPhoneNumberResolver
    function hasPhone(address wallet) external view override returns (bool) {
        return addressToPhone[wallet] != bytes32(0);
    }

    /// @inheritdoc IPhoneNumberResolver
    function getPhoneHash(address wallet) external view override returns (bytes32) {
        return addressToPhone[wallet];
    }

    // ============ Helper Functions ============

    /// @notice Register using raw phone number string (convenience function)
    /// @param phoneNumber The phone number string
    /// @param wallet The wallet address
    function registerPhoneString(string calldata phoneNumber, address wallet) external onlyOwner {
        bytes32 phoneHash = keccak256(abi.encodePacked(phoneNumber));

        if (wallet == address(0)) revert InvalidWallet();
        if (_isRegistered[phoneHash]) revert PhoneAlreadyRegistered();
        if (addressToPhone[wallet] != bytes32(0)) revert WalletAlreadyHasPhone();

        phoneToAddress[phoneHash] = wallet;
        addressToPhone[wallet] = phoneHash;
        _isRegistered[phoneHash] = true;

        emit PhoneRegistered(phoneHash, wallet);
    }

    /// @notice Resolve using raw phone number string
    /// @param phoneNumber The phone number string
    /// @return wallet The associated wallet address
    function resolveString(string calldata phoneNumber) external view returns (address wallet) {
        bytes32 phoneHash = keccak256(abi.encodePacked(phoneNumber));
        return phoneToAddress[phoneHash];
    }
}
