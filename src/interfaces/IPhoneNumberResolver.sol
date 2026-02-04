// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IPhoneNumberResolver
/// @notice Interface for resolving phone numbers to wallet addresses
/// @author dev_jaytee
interface IPhoneNumberResolver {
    /// @notice Resolve a phone number hash to a wallet address
    /// @param phoneHash The keccak256 hash of the phone number
    /// @return wallet The associated wallet address (address(0) if not found)
    function resolve(bytes32 phoneHash) external view returns (address wallet);

    /// @notice Compute the hash of a phone number
    /// @param phoneNumber The phone number string (e.g., "+254712345678")
    /// @return The keccak256 hash
    function computePhoneHash(string calldata phoneNumber) external pure returns (bytes32);

    /// @notice Check if a phone number is registered
    /// @param phoneHash The phone number hash
    /// @return True if registered
    function isRegistered(bytes32 phoneHash) external view returns (bool);

    /// @notice Check if an address has a registered phone number
    /// @param wallet The wallet address to check
    /// @return True if the address has a registered phone number
    function hasPhone(address wallet) external view returns (bool);

    /// @notice Get the phone hash for a wallet address (reverse lookup)
    /// @param wallet The wallet address
    /// @return The phone hash (bytes32(0) if not registered)
    function getPhoneHash(address wallet) external view returns (bytes32);
}
