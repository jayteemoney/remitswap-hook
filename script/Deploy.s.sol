// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script, console } from "forge-std/Script.sol";
import { IPoolManager } from "v4-core/src/interfaces/IPoolManager.sol";
import { Hooks } from "v4-core/src/libraries/Hooks.sol";
import { HookMiner } from "v4-periphery/src/utils/HookMiner.sol";

import { RemitSwapHook } from "../src/RemitSwapHook.sol";
import { AllowlistCompliance } from "../src/compliance/AllowlistCompliance.sol";
import { PhoneNumberResolver } from "../src/compliance/PhoneNumberResolver.sol";
import { ICompliance } from "../src/interfaces/ICompliance.sol";
import { IPhoneNumberResolver } from "../src/interfaces/IPhoneNumberResolver.sol";

/// @title DeployRemitSwapHook
/// @notice Deployment script for RemitSwapHook and supporting contracts
/// @dev Run with: forge script script/Deploy.s.sol:DeployRemitSwapHook --rpc-url <RPC_URL> --broadcast
contract DeployRemitSwapHook is Script {
    // ============ Deployment Configuration ============

    // Base Mainnet PoolManager
    address constant BASE_POOL_MANAGER = 0x498581fF718922c3f8e6A244956aF099B2652b2b;

    // Base Sepolia PoolManager
    address constant BASE_SEPOLIA_POOL_MANAGER = 0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829;

    // USDT on Base
    address constant BASE_USDT = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2;

    // USDC on Base (alternative stablecoin)
    address constant BASE_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // ============ Deployment State ============

    AllowlistCompliance public compliance;
    PhoneNumberResolver public phoneResolver;
    RemitSwapHook public hook;

    // ============ Main Deployment Function ============

    function run() external virtual {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address feeCollector = vm.envOr("FEE_COLLECTOR", vm.addr(deployerPrivateKey));

        // Determine network and set pool manager
        address poolManager;
        address supportedToken;

        uint256 chainId = block.chainid;
        if (chainId == 8453) {
            // Base Mainnet
            poolManager = BASE_POOL_MANAGER;
            supportedToken = BASE_USDT;
            console.log("Deploying to Base Mainnet");
        } else if (chainId == 84532) {
            // Base Sepolia
            poolManager = BASE_SEPOLIA_POOL_MANAGER;
            supportedToken = vm.envOr("SUPPORTED_TOKEN", address(0));
            require(supportedToken != address(0), "Set SUPPORTED_TOKEN for testnet");
            console.log("Deploying to Base Sepolia");
        } else {
            // Local or custom network
            poolManager = vm.envAddress("POOL_MANAGER");
            supportedToken = vm.envAddress("SUPPORTED_TOKEN");
            console.log("Deploying to custom network:", chainId);
        }

        console.log("Pool Manager:", poolManager);
        console.log("Supported Token:", supportedToken);
        console.log("Fee Collector:", feeCollector);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy AllowlistCompliance
        compliance = new AllowlistCompliance();
        console.log("AllowlistCompliance deployed at:", address(compliance));

        // 2. Deploy PhoneNumberResolver
        phoneResolver = new PhoneNumberResolver();
        console.log("PhoneNumberResolver deployed at:", address(phoneResolver));

        // 3. Deploy RemitSwapHook with address mining
        hook = _deployHook(IPoolManager(poolManager), feeCollector, supportedToken);
        console.log("RemitSwapHook deployed at:", address(hook));

        // 4. Configure compliance to accept hook
        compliance.setHook(address(hook));
        console.log("Compliance configured with hook");

        // 5. Add deployer to allowlist for testing
        compliance.addToAllowlist(vm.addr(deployerPrivateKey), 0);
        console.log("Deployer added to allowlist");

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n========== DEPLOYMENT SUMMARY ==========");
        console.log("Chain ID:", chainId);
        console.log("AllowlistCompliance:", address(compliance));
        console.log("PhoneNumberResolver:", address(phoneResolver));
        console.log("RemitSwapHook:", address(hook));
        console.log("=========================================\n");
    }

    // ============ Hook Deployment with Address Mining ============

    function _deployHook(IPoolManager poolManager, address feeCollector, address supportedToken)
        internal
        returns (RemitSwapHook)
    {
        // Calculate required flags for hook permissions
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);

        // Prepare constructor arguments
        bytes memory constructorArgs =
            abi.encode(poolManager, compliance, phoneResolver, feeCollector, supportedToken);

        // Find a valid salt that produces an address with correct flags
        console.log("Mining hook address with flags:", flags);

        (address hookAddress, bytes32 salt) =
            HookMiner.find(address(this), flags, type(RemitSwapHook).creationCode, constructorArgs);

        console.log("Found valid hook address:", hookAddress);
        console.log("Using salt:", vm.toString(salt));

        // Deploy the hook at the computed address
        RemitSwapHook newHook = new RemitSwapHook{ salt: salt }(
            poolManager,
            ICompliance(address(compliance)),
            IPhoneNumberResolver(address(phoneResolver)),
            feeCollector,
            supportedToken
        );

        // Verify deployment address matches computed address
        require(address(newHook) == hookAddress, "Hook address mismatch!");

        return newHook;
    }
}

/// @title DeployToBaseSepolia
/// @notice Convenience script for Base Sepolia testnet deployment
/// @dev Run with: forge script script/Deploy.s.sol:DeployToBaseSepolia --rpc-url base-sepolia --broadcast
contract DeployToBaseSepolia is Script {
    function run() external {
        console.log("Deploying to Base Sepolia...");

        // Load environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address feeCollector = vm.envOr("FEE_COLLECTOR", vm.addr(deployerPrivateKey));
        address supportedToken = vm.envAddress("SUPPORTED_TOKEN");

        address poolManager = 0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829;

        console.log("Pool Manager:", poolManager);
        console.log("Supported Token:", supportedToken);
        console.log("Fee Collector:", feeCollector);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts
        AllowlistCompliance compliance = new AllowlistCompliance();
        console.log("AllowlistCompliance:", address(compliance));

        PhoneNumberResolver phoneResolver = new PhoneNumberResolver();
        console.log("PhoneNumberResolver:", address(phoneResolver));

        // Deploy hook with address mining
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        bytes memory constructorArgs =
            abi.encode(poolManager, compliance, phoneResolver, feeCollector, supportedToken);

        (address hookAddress, bytes32 salt) =
            HookMiner.find(address(this), flags, type(RemitSwapHook).creationCode, constructorArgs);

        RemitSwapHook hook = new RemitSwapHook{ salt: salt }(
            IPoolManager(poolManager),
            ICompliance(address(compliance)),
            IPhoneNumberResolver(address(phoneResolver)),
            feeCollector,
            supportedToken
        );
        require(address(hook) == hookAddress, "Hook address mismatch");
        console.log("RemitSwapHook:", address(hook));

        // Configure
        compliance.setHook(address(hook));
        compliance.addToAllowlist(vm.addr(deployerPrivateKey), 0);

        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
    }
}

/// @title DeployToBase
/// @notice Convenience script for Base mainnet deployment
/// @dev Run with: forge script script/Deploy.s.sol:DeployToBase --rpc-url base --broadcast
contract DeployToBase is Script {
    function run() external {
        console.log("!!! WARNING: Deploying to Base Mainnet !!!");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address feeCollector = vm.envOr("FEE_COLLECTOR", vm.addr(deployerPrivateKey));

        address poolManager = 0x498581fF718922c3f8e6A244956aF099B2652b2b;
        address supportedToken = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2; // USDT on Base

        console.log("Pool Manager:", poolManager);
        console.log("Supported Token:", supportedToken);
        console.log("Fee Collector:", feeCollector);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts
        AllowlistCompliance compliance = new AllowlistCompliance();
        console.log("AllowlistCompliance:", address(compliance));

        PhoneNumberResolver phoneResolver = new PhoneNumberResolver();
        console.log("PhoneNumberResolver:", address(phoneResolver));

        // Deploy hook with address mining
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        bytes memory constructorArgs =
            abi.encode(poolManager, compliance, phoneResolver, feeCollector, supportedToken);

        (address hookAddress, bytes32 salt) =
            HookMiner.find(address(this), flags, type(RemitSwapHook).creationCode, constructorArgs);

        RemitSwapHook hook = new RemitSwapHook{ salt: salt }(
            IPoolManager(poolManager),
            ICompliance(address(compliance)),
            IPhoneNumberResolver(address(phoneResolver)),
            feeCollector,
            supportedToken
        );
        require(address(hook) == hookAddress, "Hook address mismatch");
        console.log("RemitSwapHook:", address(hook));

        // Configure
        compliance.setHook(address(hook));
        compliance.addToAllowlist(vm.addr(deployerPrivateKey), 0);

        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
    }
}
