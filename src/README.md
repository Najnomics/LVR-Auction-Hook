# LVR Auction Hook - Main Project

This directory contains the **core business logic** for the LVR Auction Hook system.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    MAIN PROJECT (/src)                     │
│                   Business Logic Only                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 AVS CONNECTORS (/avs-new)                  │
│              Distributed Compute Layer                     │
└─────────────────────────────────────────────────────────────┘
```

## Files in This Directory

### ✅ Core Business Logic
- **`LVRAuctionHook.sol`** - Main Uniswap V4 hook with all auction functionality
- **`ChainlinkPriceOracle.sol`** - Price monitoring and oracle integration
- **`ProductionPriceFeedConfig.sol`** - Production price feed configurations

### ✅ Supporting Infrastructure
- **`interfaces/`** - Business logic interfaces
  - `IAVSDirectory.sol` - AVS directory interface
  - `IPriceOracle.sol` - Price oracle interface
- **`libraries/`** - Auction utility libraries
  - `AuctionLib.sol` - Core auction logic
  - `AuctionLibFixed.sol` - Enhanced auction utilities
- **`utils/`** - Helper utilities
  - `HookMiner.sol` - Hook address mining utility

### ❌ Legacy Files
- **`LVRAuctionServiceManager.sol.legacy`** - Old non-DevKit AVS implementation
  - **Replaced by:** `/avs-new/contracts/src/l1-contracts/LVRAuctionServiceManager.sol`
  - **Reason:** Judges requested DevKit template compliance

## DevKit Compliance

The project now follows proper DevKit architecture:

1. **Main Project** (this directory): Contains all auction business logic
2. **AVS Component** (`/avs-new/`): Contains only EigenLayer connectors and distributed compute coordination

### AVS Integration

The DevKit-compliant AVS components are located in `/avs-new/` and include:

- **L1 Connector**: `LVRAuctionServiceManager.sol` (extends `TaskAVSRegistrarBase`)
- **L2 Connector**: `LVRAuctionTaskHook.sol` (implements `IAVSTaskHook`)
- **Go Performer**: Task orchestration and consensus coordination

## Deployment

1. **Deploy main contracts** (this directory) first
2. **Deploy AVS connectors** (`/avs-new/`) with main contract addresses
3. **Configure AVS** to interface with deployed main contracts

## Testing

Main project tests are located in `/test/` at the project root.
AVS connector tests are in `/avs-new/contracts/test/`.