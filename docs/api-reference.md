# LVR Auction Hook - API Reference

## Overview

This document provides comprehensive API documentation for the LVR Auction Hook system, including smart contract interfaces, AVS APIs, and monitoring endpoints.

## Smart Contract APIs

### LVRAuctionHook.sol

#### Core Functions

##### `initialize(address _avsServiceManager)`
Initializes the LVR Auction Hook with the AVS Service Manager.

**Parameters:**
- `_avsServiceManager` (address): Address of the AVS Service Manager contract

**Access:** Only owner

**Events:**
- `HookInitialized(address indexed avsServiceManager, uint256 timestamp)`

##### `enableAuctionForPool(bytes32 poolId, bool enabled)`
Enables or disables auctions for a specific pool.

**Parameters:**
- `poolId` (bytes32): Pool identifier
- `enabled` (bool): Whether to enable auctions

**Access:** Only owner

**Events:**
- `AuctionEnabled(bytes32 indexed poolId, bool enabled)`

##### `updateConfig(LVRAuctionConfig calldata newConfig)`
Updates the LVR auction configuration.

**Parameters:**
- `newConfig` (LVRAuctionConfig): New configuration parameters

**Access:** Only owner

**Events:**
- `ConfigUpdated(LVRAuctionConfig newConfig)`

##### `submitPriceDiscrepancy(bytes32 poolId, uint256 dexPrice, uint256 cexPrice, uint256 timestamp)`
Submits a price discrepancy for auction initiation.

**Parameters:**
- `poolId` (bytes32): Pool identifier
- `dexPrice` (uint256): DEX price
- `cexPrice` (uint256): CEX price
- `timestamp` (uint256): Price timestamp

**Access:** Only AVS Service Manager

**Events:**
- `PriceDiscrepancySubmitted(bytes32 indexed poolId, uint256 dexPrice, uint256 cexPrice, uint256 timestamp)`

##### `submitSealedBid(bytes32 auctionId, bytes32 sealedBid)`
Submits a sealed bid for an auction.

**Parameters:**
- `auctionId` (bytes32): Auction identifier
- `sealedBid` (bytes32): Sealed bid hash

**Access:** Only bidders

**Events:**
- `SealedBidSubmitted(bytes32 indexed auctionId, address indexed bidder, bytes32 sealedBid)`

##### `revealBid(bytes32 auctionId, uint256 bidAmount, uint256 nonce)`
Reveals a sealed bid.

**Parameters:**
- `auctionId` (bytes32): Auction identifier
- `bidAmount` (uint256): Bid amount
- `nonce` (uint256): Nonce used for sealing

**Access:** Only bidder

**Events:**
- `BidRevealed(bytes32 indexed auctionId, address indexed bidder, uint256 bidAmount)`

##### `finalizeAuction(bytes32 auctionId)`
Finalizes an auction and determines the winner.

**Parameters:**
- `auctionId` (bytes32): Auction identifier

**Access:** Only AVS Service Manager

**Events:**
- `AuctionFinalized(bytes32 indexed auctionId, address indexed winner, uint256 winningBid)`

#### View Functions

##### `getAuctionInfo(bytes32 auctionId) returns (AuctionInfo memory)`
Returns information about a specific auction.

**Parameters:**
- `auctionId` (bytes32): Auction identifier

**Returns:**
- `AuctionInfo`: Auction information struct

##### `getPoolConfig(bytes32 poolId) returns (PoolConfig memory)`
Returns configuration for a specific pool.

**Parameters:**
- `poolId` (bytes32): Pool identifier

**Returns:**
- `PoolConfig`: Pool configuration struct

##### `getAuctionStats() returns (AuctionStats memory)`
Returns overall auction statistics.

**Returns:**
- `AuctionStats`: Auction statistics struct

##### `isActive() returns (bool)`
Returns whether the hook is active.

**Returns:**
- `bool`: Active status

#### Emergency Functions

##### `pause()`
Pauses the hook system.

**Access:** Only owner

**Events:**
- `SystemPaused(uint256 timestamp)`

##### `unpause()`
Unpauses the hook system.

**Access:** Only owner

**Events:**
- `SystemUnpaused(uint256 timestamp)`

##### `emergencyWithdraw()`
Emergency withdrawal of funds.

**Access:** Only owner

**Events:**
- `EmergencyWithdrawal(address indexed to, uint256 amount)`

### AuctionLibrary.sol

#### Core Functions

##### `createAuction(AuctionParams memory params) returns (bytes32)`
Creates a new auction.

**Parameters:**
- `params` (AuctionParams): Auction parameters

**Returns:**
- `bytes32`: Auction identifier

##### `submitBid(bytes32 auctionId, address bidder, uint256 amount) returns (bool)`
Submits a bid for an auction.

**Parameters:**
- `auctionId` (bytes32): Auction identifier
- `bidder` (address): Bidder address
- `amount` (uint256): Bid amount

**Returns:**
- `bool`: Success status

##### `revealBid(bytes32 auctionId, address bidder, uint256 amount, uint256 nonce) returns (bool)`
Reveals a sealed bid.

**Parameters:**
- `auctionId` (bytes32): Auction identifier
- `bidder` (address): Bidder address
- `amount` (uint256): Bid amount
- `nonce` (uint256): Nonce used for sealing

**Returns:**
- `bool`: Success status

##### `finalizeAuction(bytes32 auctionId) returns (address, uint256)`
Finalizes an auction and returns the winner.

**Parameters:**
- `auctionId` (bytes32): Auction identifier

**Returns:**
- `address`: Winner address
- `uint256`: Winning bid amount

#### View Functions

##### `getAuction(bytes32 auctionId) returns (Auction memory)`
Returns auction information.

**Parameters:**
- `auctionId` (bytes32): Auction identifier

**Returns:**
- `Auction`: Auction struct

##### `getBids(bytes32 auctionId) returns (Bid[] memory)`
Returns all bids for an auction.

**Parameters:**
- `auctionId` (bytes32): Auction identifier

**Returns:**
- `Bid[]`: Array of bids

##### `isAuctionActive(bytes32 auctionId) returns (bool)`
Checks if an auction is active.

**Parameters:**
- `auctionId` (bytes32): Auction identifier

**Returns:**
- `bool`: Active status

### PriceOracle.sol

#### Core Functions

##### `updatePrice(bytes32 poolId, uint256 price, uint256 timestamp)`
Updates the price for a pool.

**Parameters:**
- `poolId` (bytes32): Pool identifier
- `price` (uint256): Price value
- `timestamp` (uint256): Price timestamp

**Access:** Only owner

**Events:**
- `PriceUpdated(bytes32 indexed poolId, uint256 price, uint256 timestamp)`

##### `getPrice(bytes32 poolId) returns (uint256, uint256)`
Gets the current price for a pool.

**Parameters:**
- `poolId` (bytes32): Pool identifier

**Returns:**
- `uint256`: Price value
- `uint256`: Timestamp

##### `getPriceHistory(bytes32 poolId, uint256 count) returns (PricePoint[] memory)`
Gets price history for a pool.

**Parameters:**
- `poolId` (bytes32): Pool identifier
- `count` (uint256): Number of historical prices

**Returns:**
- `PricePoint[]`: Array of price points

#### View Functions

##### `isPriceValid(bytes32 poolId) returns (bool)`
Checks if the price is valid and recent.

**Parameters:**
- `poolId` (bytes32): Pool identifier

**Returns:**
- `bool`: Valid status

##### `getPriceAge(bytes32 poolId) returns (uint256)`
Gets the age of the current price.

**Parameters:**
- `poolId` (bytes32): Pool identifier

**Returns:**
- `uint256`: Price age in seconds

## AVS APIs

### LVRAuctionServiceManager.sol

#### Core Functions

##### `registerOperator(address operator, string memory metadataURI)`
Registers a new operator.

**Parameters:**
- `operator` (address): Operator address
- `metadataURI` (string): Operator metadata URI

**Access:** Only owner

**Events:**
- `OperatorRegistered(address indexed operator, string metadataURI)`

##### `deregisterOperator(address operator)`
Deregisters an operator.

**Parameters:**
- `operator` (address): Operator address

**Access:** Only owner

**Events:**
- `OperatorDeregistered(address indexed operator)`

##### `submitPriceDiscrepancy(bytes32 poolId, uint256 dexPrice, uint256 cexPrice)`
Submits a price discrepancy for auction initiation.

**Parameters:**
- `poolId` (bytes32): Pool identifier
- `dexPrice` (uint256): DEX price
- `cexPrice` (uint256): CEX price

**Access:** Only registered operators

**Events:**
- `PriceDiscrepancySubmitted(bytes32 indexed poolId, uint256 dexPrice, uint256 cexPrice)`

##### `submitSealedBid(bytes32 auctionId, bytes32 sealedBid)`
Submits a sealed bid for an auction.

**Parameters:**
- `auctionId` (bytes32): Auction identifier
- `sealedBid` (bytes32): Sealed bid hash

**Access:** Only registered operators

**Events:**
- `SealedBidSubmitted(bytes32 indexed auctionId, address indexed bidder, bytes32 sealedBid)`

##### `revealBid(bytes32 auctionId, uint256 bidAmount, uint256 nonce)`
Reveals a sealed bid.

**Parameters:**
- `auctionId` (bytes32): Auction identifier
- `bidAmount` (uint256): Bid amount
- `nonce` (uint256): Nonce used for sealing

**Access:** Only bidder

**Events:**
- `BidRevealed(bytes32 indexed auctionId, address indexed bidder, uint256 bidAmount)`

##### `finalizeAuction(bytes32 auctionId)`
Finalizes an auction and determines the winner.

**Parameters:**
- `auctionId` (bytes32): Auction identifier

**Access:** Only registered operators

**Events:**
- `AuctionFinalized(bytes32 indexed auctionId, address indexed winner, uint256 winningBid)`

#### View Functions

##### `isOperatorRegistered(address operator) returns (bool)`
Checks if an operator is registered.

**Parameters:**
- `operator` (address): Operator address

**Returns:**
- `bool`: Registration status

##### `getOperatorInfo(address operator) returns (OperatorInfo memory)`
Returns operator information.

**Parameters:**
- `operator` (address): Operator address

**Returns:**
- `OperatorInfo`: Operator information struct

##### `getAuctionInfo(bytes32 auctionId) returns (AuctionInfo memory)`
Returns auction information.

**Parameters:**
- `auctionId` (bytes32): Auction identifier

**Returns:**
- `AuctionInfo`: Auction information struct

### LVRAuctionTaskHook.sol

#### Core Functions

##### `validatePreTaskCreation(bytes calldata taskData) returns (bool)`
Validates task data before creation.

**Parameters:**
- `taskData` (bytes): Task data

**Returns:**
- `bool`: Validation result

##### `handlePostTaskCreation(bytes32 taskId, bytes calldata taskData)`
Handles post-task creation logic.

**Parameters:**
- `taskId` (bytes32): Task identifier
- `taskData` (bytes): Task data

**Access:** Only AVS Service Manager

**Events:**
- `TaskCreated(bytes32 indexed taskId, bytes taskData)`

##### `validatePreTaskResultSubmission(bytes32 taskId, bytes calldata resultData) returns (bool)`
Validates task result data before submission.

**Parameters:**
- `taskId` (bytes32): Task identifier
- `resultData` (bytes): Result data

**Returns:**
- `bool`: Validation result

##### `handlePostTaskResultSubmission(bytes32 taskId, bytes calldata resultData)`
Handles post-task result submission logic.

**Parameters:**
- `taskId` (bytes32): Task identifier
- `resultData` (bytes): Result data

**Access:** Only AVS Service Manager

**Events:**
- `TaskResultSubmitted(bytes32 indexed taskId, bytes resultData)`

##### `calculateTaskFee(bytes32 taskId, bytes calldata taskData) returns (uint256)`
Calculates the fee for a task.

**Parameters:**
- `taskId` (bytes32): Task identifier
- `taskData` (bytes): Task data

**Returns:**
- `uint256`: Task fee

#### View Functions

##### `getTaskInfo(bytes32 taskId) returns (TaskInfo memory)`
Returns task information.

**Parameters:**
- `taskId` (bytes32): Task identifier

**Returns:**
- `TaskInfo`: Task information struct

##### `isTaskValid(bytes32 taskId) returns (bool)`
Checks if a task is valid.

**Parameters:**
- `taskId` (bytes32): Task identifier

**Returns:**
- `bool`: Valid status

## Monitoring APIs

### Health Check Endpoint

#### `GET /health`
Returns the health status of the AVS performer.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": 1640995200,
  "version": "1.0.0",
  "uptime": 3600,
  "services": {
    "rpc": "healthy",
    "database": "healthy",
    "monitoring": "healthy"
  }
}
```

### Metrics Endpoint

#### `GET /metrics`
Returns Prometheus-compatible metrics.

**Response:**
```
# HELP lvr_auction_tasks_total Total number of tasks processed
# TYPE lvr_auction_tasks_total counter
lvr_auction_tasks_total{status="success"} 100
lvr_auction_tasks_total{status="failed"} 5

# HELP lvr_auction_auctions_total Total number of auctions created
# TYPE lvr_auction_auctions_total counter
lvr_auction_auctions_total 50

# HELP lvr_auction_rewards_total Total rewards distributed
# TYPE lvr_auction_rewards_total counter
lvr_auction_rewards_total 1000.5
```

### Task Status Endpoint

#### `GET /tasks/status`
Returns the status of all tasks.

**Response:**
```json
{
  "total_tasks": 100,
  "active_tasks": 10,
  "completed_tasks": 85,
  "failed_tasks": 5,
  "tasks": [
    {
      "task_id": "0x123...",
      "type": "price_monitoring",
      "status": "active",
      "created_at": 1640995200,
      "updated_at": 1640995260
    }
  ]
}
```

### Auction Status Endpoint

#### `GET /auctions/status`
Returns the status of all auctions.

**Response:**
```json
{
  "total_auctions": 50,
  "active_auctions": 5,
  "completed_auctions": 40,
  "failed_auctions": 5,
  "auctions": [
    {
      "auction_id": "0x456...",
      "pool_id": "0x789...",
      "status": "active",
      "start_time": 1640995200,
      "end_time": 1640998800,
      "bidders": 3
    }
  ]
}
```

## Data Structures

### Core Structs

```solidity
struct LVRAuctionConfig {
    uint256 priceDiscrepancyThresholdBps;
    uint256 auctionDuration;
    uint256 lpSharePercentage;
    uint256 operatorSharePercentage;
    uint256 slashingThreshold;
    bool isActive;
}

struct PoolConfig {
    bool auctionEnabled;
    uint256 customThresholdBps;
    uint256 lastAuctionTime;
    uint256 totalAuctions;
}

struct AuctionInfo {
    bytes32 auctionId;
    bytes32 poolId;
    uint256 mevAmount;
    uint256 startTime;
    uint256 endTime;
    address winner;
    uint256 winningBid;
    AuctionStatus status;
}

struct AuctionStats {
    uint256 totalAuctions;
    uint256 totalMEVDistributed;
    uint256 totalLPRewards;
    uint256 totalOperatorRewards;
    uint256 averageAuctionDuration;
}

struct OperatorInfo {
    address operator;
    string metadataURI;
    uint256 totalTasks;
    uint256 successfulTasks;
    uint256 totalRewards;
    bool isActive;
}

struct TaskInfo {
    bytes32 taskId;
    TaskType taskType;
    TaskStatus status;
    uint256 createdAt;
    uint256 updatedAt;
    bytes taskData;
    bytes resultData;
}
```

### Enums

```solidity
enum AuctionStatus {
    Pending,
    Active,
    Completed,
    Failed,
    Cancelled
}

enum TaskType {
    PriceMonitoring,
    AuctionCoordination,
    AuctionResolution,
    ProceedsDistribution
}

enum TaskStatus {
    Pending,
    Active,
    Completed,
    Failed,
    Cancelled
}
```

## Error Codes

### Common Errors

- `UNAUTHORIZED`: Caller is not authorized
- `INVALID_POOL`: Pool does not exist or is invalid
- `AUCTION_NOT_FOUND`: Auction does not exist
- `AUCTION_EXPIRED`: Auction has expired
- `INVALID_BID`: Bid is invalid or too low
- `BID_ALREADY_SUBMITTED`: Bid already submitted
- `AUCTION_NOT_ACTIVE`: Auction is not active
- `INVALID_PRICE`: Price data is invalid
- `THRESHOLD_NOT_MET`: Price discrepancy below threshold
- `SYSTEM_PAUSED`: System is paused

### Error Handling

```solidity
// Example error handling
if (msg.sender != owner) {
    revert UNAUTHORIZED();
}

if (auction.status != AuctionStatus.Active) {
    revert AUCTION_NOT_ACTIVE();
}

if (bidAmount < minimumBid) {
    revert INVALID_BID();
}
```

## Rate Limits

### API Rate Limits

- **Health Check**: 100 requests/minute
- **Metrics**: 60 requests/minute
- **Task Status**: 30 requests/minute
- **Auction Status**: 30 requests/minute

### Contract Rate Limits

- **Price Submission**: 10 requests/minute per operator
- **Bid Submission**: 5 requests/minute per bidder
- **Auction Creation**: 1 request/minute per pool

## Authentication

### API Authentication

All API endpoints require authentication using API keys:

```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://localhost:8081/health
```

### Contract Authentication

Contract functions use role-based access control:

- **Owner**: Full administrative access
- **AVS Service Manager**: Task and auction management
- **Registered Operators**: Task execution and bidding
- **Bidders**: Bid submission and revelation

## Examples

### Creating an Auction

```javascript
// Submit price discrepancy
await lvrHook.submitPriceDiscrepancy(
    poolId,
    dexPrice,
    cexPrice,
    timestamp
);

// Submit sealed bid
const sealedBid = ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
        ["uint256", "uint256"],
        [bidAmount, nonce]
    )
);

await lvrHook.submitSealedBid(auctionId, sealedBid);

// Reveal bid
await lvrHook.revealBid(auctionId, bidAmount, nonce);
```

### Monitoring System Health

```javascript
// Check health
const health = await fetch('/health').then(r => r.json());
console.log('System status:', health.status);

// Get metrics
const metrics = await fetch('/metrics').then(r => r.text());
console.log('Metrics:', metrics);

// Check task status
const tasks = await fetch('/tasks/status').then(r => r.json());
console.log('Active tasks:', tasks.active_tasks);
```

## Conclusion

This API reference provides comprehensive documentation for all interfaces and endpoints in the LVR Auction Hook system. For additional information, refer to the technical specification and deployment guide.
