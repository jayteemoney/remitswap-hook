# RemitSwapHook

A Uniswap v4 hook enabling low-cost, compliant cross-border remittances with group funding capabilities.

## Overview

RemitSwapHook solves the high-cost problem of cross-border remittances (averaging 6.2% globally) by leveraging Uniswap v4's hook architecture to provide:

- **< 1% total fees** vs 6-15% traditional services
- **On-chain compliance** via allowlist (upgradeable to Worldcoin)
- **Group contributions** - multiple senders can pool funds for one recipient
- **USDT corridor** - stable, global transfers
- **Instant settlement** - blockchain speed, not days

## Features

### Core Functionality
- **Remittance Creation** - Create remittances with target amounts and optional expiry
- **Group Funding** - Multiple contributors can fund a single remittance
- **Auto-Release** - Automatic release when target is met (configurable)
- **Manual Release** - Recipients can claim when ready
- **Cancellation & Refunds** - Creators can cancel with full contributor refunds
- **Expiry Handling** - Contributors can claim refunds after expiry

### Compliance
- **Allowlist-based KYC** - Simple allowlist for verified users
- **Daily Limits** - Configurable per-user daily transfer limits
- **Blocklist** - Sanctions compliance via blocklist
- **Upgradeable** - Interface supports future Worldcoin integration

### Phone Integration
- **Phone-to-Address Resolution** - Send to phone numbers instead of addresses
- **Privacy-Preserving** - Phone numbers stored as hashes

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      RemitSwapHook.sol                       │
│                    (Main Hook Contract)                      │
├──────────────────────────────────────────────────────────────┤
│  - beforeSwap()     → Compliance verification                │
│  - afterSwap()      → Escrow deposit + tracking              │
│  - createRemittance() → Initialize new remittance            │
│  - releaseRemittance() → Recipient claims funds              │
│  - cancelRemittance()  → Creator cancels + refunds           │
└──────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│ ICompliance.sol  │ │ RemitTypes.sol   │ │ PhoneResolver    │
│   (Interface)    │ │  (Lib/Types)     │ │     .sol         │
└──────────────────┘ └──────────────────┘ └──────────────────┘
         │
         ▼
┌──────────────────┐
│ AllowlistCompl.  │
│     .sol         │
└──────────────────┘
```

## Installation

```bash
# Clone the repository
git clone https://github.com/jayteemoney/remitswap-hook.git
cd remitswap-hook

# Install dependencies
forge install

# Build
forge build

# Test
forge test
```

## Usage

### Creating a Remittance

```solidity
// Create a remittance for 1000 USDT with auto-release enabled
uint256 remittanceId = hook.createRemittance(
    recipientAddress,    // Recipient wallet
    1000 * 1e6,         // Target amount (1000 USDT)
    0,                   // No expiry (0 = never expires)
    bytes32(0),          // Purpose hash (optional)
    true                 // Auto-release when target met
);
```

### Contributing to a Remittance

```solidity
// Approve USDT spending first
usdt.approve(address(hook), amount);

// Contribute directly
hook.contributeDirectly(remittanceId, 100 * 1e6); // Contribute 100 USDT
```

### Creating Remittance by Phone Number

```solidity
// Create remittance using recipient's phone number
bytes32 phoneHash = keccak256(abi.encodePacked("+254712345678"));
uint256 remittanceId = hook.createRemittanceByPhone(
    phoneHash,
    1000 * 1e6,
    0,
    bytes32(0),
    true
);
```

### Releasing Funds (Manual)

```solidity
// Only recipient can release (if auto-release is disabled)
hook.releaseRemittance(remittanceId);
```

### Cancelling a Remittance

```solidity
// Only creator can cancel - all contributors are refunded
hook.cancelRemittance(remittanceId);
```

## Contract Addresses

### Base Sepolia (Testnet)
| Contract | Address |
|----------|---------|
| RemitSwapHook | `TBD` |
| AllowlistCompliance | `TBD` |
| PhoneNumberResolver | `TBD` |

### Base Mainnet
| Contract | Address |
|----------|---------|
| RemitSwapHook | `TBD` |
| AllowlistCompliance | `TBD` |
| PhoneNumberResolver | `TBD` |

## Testing

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test
forge test --match-test test_CreateRemittance_Success -vvv

# Gas report
forge test --gas-report

# Coverage
forge coverage
```

### Test Results
- 30+ unit tests covering all core functionality
- Fuzz tests for contribution amounts and fee calculations
- Edge case coverage for expiry, cancellation, and compliance

## Security Considerations

| Vector | Mitigation |
|--------|------------|
| Reentrancy | OpenZeppelin ReentrancyGuard on state-changing functions |
| Compliance Bypass | beforeSwap check enforced by PoolManager |
| Stuck Funds | Expiry mechanism + emergency admin withdrawal |
| Front-running | No MEV opportunity - fixed fee, no price impact |

## Fee Structure

- **Platform Fee**: 0.5% (50 basis points)
- **Maximum Fee**: 5% (500 basis points)
- Fees are deducted on release and sent to the fee collector

## Development

### Tech Stack
- **Solidity**: 0.8.26
- **Framework**: Foundry
- **Dependencies**: Uniswap v4-core, v4-periphery, OpenZeppelin

### Directory Structure
```
remitswap-hook/
├── src/
│   ├── RemitSwapHook.sol           # Main hook contract
│   ├── compliance/
│   │   ├── AllowlistCompliance.sol # Allowlist implementation
│   │   └── PhoneNumberResolver.sol # Phone-to-address mapping
│   ├── interfaces/
│   │   ├── ICompliance.sol         # Compliance interface
│   │   ├── IPhoneNumberResolver.sol
│   │   └── IRemitSwapHook.sol
│   └── libraries/
│       └── RemitTypes.sol          # Shared types and events
├── test/
│   ├── RemitSwapHook.t.sol         # Main test suite
│   └── utils/
│       └── HookTest.sol            # Test utilities
└── script/
    └── Deploy.s.sol                # Deployment script
```

## Roadmap

- [x] Phase 1: Project Setup
- [x] Phase 2: Core Contracts
- [x] Phase 3: Testing
- [ ] Phase 4: Testnet Deployment
- [ ] Phase 5: Documentation
- [ ] Phase 6: Mainnet Deployment
- [ ] Phase 7: Worldcoin Integration

## Contributing

Contributions are welcome! Please open an issue or submit a PR.

## License

MIT

## Acknowledgments

- [Uniswap Foundation](https://uniswap.org/) - v4 Hook architecture
- [Uniswap Hook Incubator](https://atrium.academy/uniswap) - UHI8 January 2026 Cohort
- [OpenZeppelin](https://openzeppelin.com/) - Security utilities

---

**Built for UHI8 - Uniswap Hook Incubator January 2026 Cohort**
