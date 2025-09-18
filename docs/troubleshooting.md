# LVR Auction Hook - Troubleshooting Guide

## Overview

This guide provides solutions to common issues encountered when developing, deploying, or operating the LVR Auction Hook system. It covers smart contract issues, AVS problems, deployment failures, and operational challenges.

## Smart Contract Issues

### Compilation Errors

#### Error: `NotPoolManager()` from `ImmutableState.sol`

**Symptoms:**
```
Error: NotPoolManager()
    --> src/hooks/LVRAuctionHook.sol:45:9
```

**Cause:** The hook is not properly initialized with the PoolManager address.

**Solution:**
```solidity
// ✅ Correct: Properly initialize the hook
constructor(IPoolManager _poolManager) {
    poolManager = _poolManager;
}

// ❌ Incorrect: Missing PoolManager initialization
constructor() {
    // Missing poolManager initialization
}
```

#### Error: `TypeError: Member "poolManager" not found`

**Symptoms:**
```
TypeError: Member "poolManager" not found or not visible after argument-dependent lookup in struct IPoolManager.
    --> src/hooks/LVRAuctionHook.sol:67:23
```

**Cause:** Incorrect interface usage or missing import.

**Solution:**
```solidity
// ✅ Correct: Proper interface usage
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

contract LVRAuctionHook is BaseHook {
    IPoolManager public immutable poolManager;
    
    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        poolManager = _poolManager;
    }
}

// ❌ Incorrect: Missing interface import
contract LVRAuctionHook {
    IPoolManager public poolManager; // Interface not imported
}
```

#### Error: `Function not found` in tests

**Symptoms:**
```
Error: Function not found: submitPriceDiscrepancy
    --> test/LVRAuctionHook.t.sol:123:15
```

**Cause:** Function not properly declared or imported.

**Solution:**
```solidity
// ✅ Correct: Proper function declaration
function submitPriceDiscrepancy(
    bytes32 poolId,
    uint256 dexPrice,
    uint256 cexPrice,
    uint256 timestamp
) external onlyAVSServiceManager {
    // Implementation
}

// ❌ Incorrect: Missing function or wrong visibility
function submitPriceDiscrepancy(
    bytes32 poolId,
    uint256 dexPrice,
    uint256 cexPrice,
    uint256 timestamp
) internal { // Should be external
    // Implementation
}
```

### Runtime Errors

#### Error: `UNAUTHORIZED` when calling functions

**Symptoms:**
```
Error: UNAUTHORIZED
    --> src/hooks/LVRAuctionHook.sol:89:9
```

**Cause:** Caller is not authorized to execute the function.

**Solution:**
```solidity
// ✅ Correct: Check authorization
function submitPriceDiscrepancy(
    bytes32 poolId,
    uint256 dexPrice,
    uint256 cexPrice,
    uint256 timestamp
) external onlyAVSServiceManager {
    require(msg.sender == avsServiceManager, "UNAUTHORIZED");
    // Implementation
}

// ❌ Incorrect: Missing authorization check
function submitPriceDiscrepancy(
    bytes32 poolId,
    uint256 dexPrice,
    uint256 cexPrice,
    uint256 timestamp
) external {
    // Missing authorization check
    // Implementation
}
```

#### Error: `AUCTION_NOT_ACTIVE` during bid submission

**Symptoms:**
```
Error: AUCTION_NOT_ACTIVE
    --> src/hooks/LVRAuctionHook.sol:156:9
```

**Cause:** Auction is not in active state.

**Solution:**
```solidity
// ✅ Correct: Check auction status
function submitSealedBid(bytes32 auctionId, bytes32 sealedBid) external {
    AuctionInfo storage auction = auctions[auctionId];
    require(auction.status == AuctionStatus.Active, "AUCTION_NOT_ACTIVE");
    require(block.timestamp < auction.endTime, "AUCTION_EXPIRED");
    // Implementation
}

// ❌ Incorrect: Missing status check
function submitSealedBid(bytes32 auctionId, bytes32 sealedBid) external {
    // Missing status check
    // Implementation
}
```

### Gas Issues

#### Error: `Out of gas` during deployment

**Symptoms:**
```
Error: Out of gas
    --> script/DeployLVR.s.sol:45:9
```

**Cause:** Contract deployment requires more gas than provided.

**Solution:**
```bash
# ✅ Correct: Increase gas limit
forge script script/DeployLVR.s.sol \
  --rpc-url $ETHEREUM_RPC_URL \
  --broadcast \
  --gas-limit 10000000

# ❌ Incorrect: Using default gas limit
forge script script/DeployLVR.s.sol \
  --rpc-url $ETHEREUM_RPC_URL \
  --broadcast
```

#### Error: `Gas estimation failed`

**Symptoms:**
```
Error: Gas estimation failed
    --> test/LVRAuctionHook.t.sol:234:15
```

**Cause:** Function execution would fail due to revert conditions.

**Solution:**
```solidity
// ✅ Correct: Check preconditions
function testSubmitBid() public {
    // Setup auction first
    createAuction();
    
    // Then submit bid
    vm.prank(bidder);
    lvrHook.submitSealedBid(auctionId, sealedBid);
}

// ❌ Incorrect: Missing setup
function testSubmitBid() public {
    // Missing auction setup
    vm.prank(bidder);
    lvrHook.submitSealedBid(auctionId, sealedBid); // Will fail
}
```

## AVS Issues

### Connection Problems

#### Error: `Failed to connect to RPC`

**Symptoms:**
```
Error: Failed to connect to RPC: dial tcp: connection refused
```

**Cause:** RPC endpoint is not accessible or incorrect.

**Solution:**
```bash
# ✅ Correct: Check RPC connectivity
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  $ETHEREUM_RPC_URL

# Check environment variables
echo $ETHEREUM_RPC_URL
echo $SEPOLIA_RPC_URL
```

#### Error: `Invalid RPC response`

**Symptoms:**
```
Error: Invalid RPC response: {"error":{"code":-32601,"message":"Method not found"}}
```

**Cause:** RPC endpoint doesn't support required methods.

**Solution:**
```go
// ✅ Correct: Validate RPC capabilities
func (w *LVRAuctionTaskWorker) validateRPC() error {
    // Test basic connectivity
    if err := w.testRPCConnection(); err != nil {
        return fmt.Errorf("RPC connection failed: %w", err)
    }
    
    // Test required methods
    if err := w.testRPCMethods(); err != nil {
        return fmt.Errorf("RPC methods not supported: %w", err)
    }
    
    return nil
}
```

### Task Processing Issues

#### Error: `Task validation failed`

**Symptoms:**
```
Error: Task validation failed: invalid task type
```

**Cause:** Task data is invalid or task type is not supported.

**Solution:**
```go
// ✅ Correct: Comprehensive task validation
func (w *LVRAuctionTaskWorker) validateTask(task *Task) error {
    if task == nil {
        return fmt.Errorf("task cannot be nil")
    }
    
    if task.ID == "" {
        return fmt.Errorf("task ID cannot be empty")
    }
    
    if task.Type == "" {
        return fmt.Errorf("task type cannot be empty")
    }
    
    // Validate task type
    switch task.Type {
    case "price_monitoring", "auction_coordination", "auction_resolution", "proceeds_distribution":
        // Valid types
    default:
        return fmt.Errorf("invalid task type: %s", task.Type)
    }
    
    // Validate task data
    if task.Data == nil {
        return fmt.Errorf("task data cannot be nil")
    }
    
    return nil
}
```

#### Error: `Task processing timeout`

**Symptoms:**
```
Error: Task processing timeout: context deadline exceeded
```

**Cause:** Task processing takes too long or gets stuck.

**Solution:**
```go
// ✅ Correct: Implement timeout handling
func (w *LVRAuctionTaskWorker) HandleTask(ctx context.Context, task *Task) error {
    // Set timeout
    ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
    defer cancel()
    
    // Process task with timeout
    done := make(chan error, 1)
    go func() {
        done <- w.processTask(ctx, task)
    }()
    
    select {
    case err := <-done:
        return err
    case <-ctx.Done():
        return fmt.Errorf("task processing timeout: %w", ctx.Err())
    }
}
```

### Operator Issues

#### Error: `Operator not registered`

**Symptoms:**
```
Error: Operator not registered
```

**Cause:** Operator is not registered in the AVS Service Manager.

**Solution:**
```bash
# ✅ Correct: Register operator
cast send $AVS_SERVICE_MANAGER_ADDRESS \
  "registerOperator(address,string)" \
  $OPERATOR_ADDRESS \
  "https://operator-metadata.com" \
  --rpc-url $ETHEREUM_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY

# ❌ Incorrect: Using unregistered operator
# Operator must be registered before use
```

#### Error: `Insufficient stake`

**Symptoms:**
```
Error: Insufficient stake
```

**Cause:** Operator doesn't have enough stake to participate.

**Solution:**
```bash
# ✅ Correct: Check and increase stake
# Check current stake
cast call $AVS_SERVICE_MANAGER_ADDRESS \
  "getOperatorStake(address)" \
  $OPERATOR_ADDRESS \
  --rpc-url $ETHEREUM_RPC_URL

# Increase stake if needed
cast send $AVS_SERVICE_MANAGER_ADDRESS \
  "increaseStake(uint256)" \
  $STAKE_AMOUNT \
  --rpc-url $ETHEREUM_RPC_URL \
  --private-key $OPERATOR_PRIVATE_KEY \
  --value $STAKE_AMOUNT
```

## Deployment Issues

### Contract Deployment Failures

#### Error: `Contract deployment failed`

**Symptoms:**
```
Error: Contract deployment failed: transaction reverted
```

**Cause:** Constructor parameters are invalid or contract initialization fails.

**Solution:**
```solidity
// ✅ Correct: Validate constructor parameters
constructor(
    IPoolManager _poolManager,
    address _avsServiceManager,
    LVRAuctionConfig memory _config
) BaseHook(_poolManager) {
    require(address(_poolManager) != address(0), "Invalid PoolManager");
    require(_avsServiceManager != address(0), "Invalid AVS Service Manager");
    require(_config.priceDiscrepancyThresholdBps > 0, "Invalid threshold");
    require(_config.auctionDuration > 0, "Invalid duration");
    
    poolManager = _poolManager;
    avsServiceManager = _avsServiceManager;
    config = _config;
}
```

#### Error: `Verification failed`

**Symptoms:**
```
Error: Verification failed: contract not found
```

**Cause:** Contract source code doesn't match deployed bytecode.

**Solution:**
```bash
# ✅ Correct: Verify with correct parameters
forge verify-contract \
  --chain-id 1 \
  --num-of-optimizations 200 \
  --watch \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  $CONTRACT_ADDRESS \
  src/hooks/LVRAuctionHook.sol:LVRAuctionHook

# ❌ Incorrect: Missing optimization count
forge verify-contract \
  --chain-id 1 \
  --watch \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  $CONTRACT_ADDRESS \
  src/hooks/LVRAuctionHook.sol:LVRAuctionHook
```

### Environment Issues

#### Error: `Environment variable not set`

**Symptoms:**
```
Error: Environment variable not set: ETHEREUM_RPC_URL
```

**Cause:** Required environment variables are not set.

**Solution:**
```bash
# ✅ Correct: Set all required environment variables
export ETHEREUM_RPC_URL="https://mainnet.infura.io/v3/YOUR_KEY"
export SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/YOUR_KEY"
export ETHERSCAN_API_KEY="YOUR_ETHERSCAN_KEY"
export OPERATOR_PRIVATE_KEY="YOUR_PRIVATE_KEY"

# Or use .env file
source .env
```

#### Error: `Invalid network configuration`

**Symptoms:**
```
Error: Invalid network configuration: unsupported chain ID
```

**Cause:** Network configuration is incorrect or unsupported.

**Solution:**
```yaml
# ✅ Correct: Valid network configuration
avs:
  name: "LVR Auction AVS"
  version: "1.0.0"

serviceManager:
  address: "0x..."
  chainId: 1  # Ethereum mainnet

taskHook:
  address: "0x..."
  chainId: 42161  # Arbitrum One

operator:
  name: "operator-name"
  privateKey: "${OPERATOR_PRIVATE_KEY}"
  stakeAmount: "1.0"
```

## Operational Issues

### Performance Problems

#### Issue: `High CPU usage`

**Symptoms:**
```
CPU usage: 95%
Memory usage: 80%
```

**Cause:** Inefficient code or resource leaks.

**Solution:**
```go
// ✅ Correct: Optimize resource usage
func (w *LVRAuctionTaskWorker) optimizePerformance() {
    // Implement connection pooling
    w.connectionPool.SetMaxOpenConns(25)
    w.connectionPool.SetMaxIdleConns(5)
    
    // Implement caching
    w.priceCache = cache.New(5*time.Minute, 10*time.Minute)
    
    // Implement rate limiting
    w.rateLimiter = rate.NewLimiter(rate.Every(time.Second), 10)
    
    // Implement batch processing
    w.batchSize = 10
}
```

#### Issue: `Memory leaks`

**Symptoms:**
```
Memory usage continuously increasing
```

**Cause:** Resources not properly cleaned up.

**Solution:**
```go
// ✅ Correct: Proper resource cleanup
func (w *LVRAuctionTaskWorker) processTask(task *Task) error {
    // Acquire resources
    conn, err := w.getConnection()
    if err != nil {
        return err
    }
    defer conn.Close() // Ensure cleanup
    
    // Process task
    result, err := w.executeTask(conn, task)
    if err != nil {
        return err
    }
    
    // Clean up task-specific resources
    defer w.cleanupTaskResources(task)
    
    return w.saveResult(result)
}
```

### Monitoring Issues

#### Issue: `Health check failing`

**Symptoms:**
```
Health check: unhealthy
```

**Cause:** System components are not responding properly.

**Solution:**
```go
// ✅ Correct: Comprehensive health check
func (w *LVRAuctionTaskWorker) healthCheck() HealthStatus {
    status := HealthStatus{
        Status:    "healthy",
        Timestamp: time.Now().Unix(),
        Services:  make(map[string]string),
    }
    
    // Check RPC connectivity
    if err := w.checkRPC(); err != nil {
        status.Services["rpc"] = "unhealthy"
        status.Status = "unhealthy"
    } else {
        status.Services["rpc"] = "healthy"
    }
    
    // Check database connectivity
    if err := w.checkDatabase(); err != nil {
        status.Services["database"] = "unhealthy"
        status.Status = "unhealthy"
    } else {
        status.Services["database"] = "healthy"
    }
    
    // Check task processing
    if err := w.checkTaskProcessing(); err != nil {
        status.Services["task_processing"] = "unhealthy"
        status.Status = "unhealthy"
    } else {
        status.Services["task_processing"] = "healthy"
    }
    
    return status
}
```

#### Issue: `Metrics not updating`

**Symptoms:**
```
Metrics endpoint returning stale data
```

**Cause:** Metrics collection is not working properly.

**Solution:**
```go
// ✅ Correct: Regular metrics collection
func (w *LVRAuctionTaskWorker) collectMetrics() {
    ticker := time.NewTicker(1 * time.Minute)
    defer ticker.Stop()
    
    for range ticker.C {
        // Collect system metrics
        metrics := SystemMetrics{
            CPUUsage:    w.getCPUUsage(),
            MemoryUsage: w.getMemoryUsage(),
            TaskCount:   w.getTaskCount(),
            ErrorRate:   w.getErrorRate(),
        }
        
        // Update metrics store
        w.metricsStore.Update(metrics)
        
        // Log metrics
        w.logger.WithFields(logrus.Fields{
            "cpu_usage":    metrics.CPUUsage,
            "memory_usage": metrics.MemoryUsage,
            "task_count":   metrics.TaskCount,
            "error_rate":   metrics.ErrorRate,
        }).Info("System metrics updated")
    }
}
```

## Emergency Procedures

### System Pause

#### Pause the entire system

```bash
# Pause smart contracts
cast send $LVR_HOOK_ADDRESS "pause()" \
  --rpc-url $ETHEREUM_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY

# Pause AVS performer
docker stop lvr-auction-avs

# Pause monitoring
docker stop lvr-auction-monitoring
```

#### Unpause the system

```bash
# Unpause smart contracts
cast send $LVR_HOOK_ADDRESS "unpause()" \
  --rpc-url $ETHEREUM_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY

# Restart AVS performer
docker start lvr-auction-avs

# Restart monitoring
docker start lvr-auction-monitoring
```

### Emergency Withdrawal

#### Withdraw all funds

```bash
# Emergency withdrawal
cast send $LVR_HOOK_ADDRESS "emergencyWithdraw()" \
  --rpc-url $ETHEREUM_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY
```

### System Recovery

#### Recover from failure

```bash
# 1. Check system status
docker ps
curl http://localhost:8081/health

# 2. Check logs
docker logs lvr-auction-avs

# 3. Restart services
docker restart lvr-auction-avs

# 4. Verify recovery
curl http://localhost:8081/health
```

## Prevention Strategies

### Regular Maintenance

1. **Monitor system health** - Set up automated monitoring
2. **Update dependencies** - Keep all dependencies updated
3. **Review logs** - Regularly review system logs
4. **Test backups** - Ensure backup and recovery procedures work
5. **Security audits** - Conduct regular security reviews

### Best Practices

1. **Input validation** - Validate all inputs
2. **Error handling** - Implement comprehensive error handling
3. **Resource management** - Properly manage resources
4. **Monitoring** - Implement comprehensive monitoring
5. **Documentation** - Keep documentation updated

## Getting Help

### Support Channels

- **GitHub Issues** - Bug reports and feature requests
- **Discord** - Community support and discussions
- **Documentation** - Comprehensive guides and references
- **Email** - Security issues and critical support

### Escalation Process

1. **Level 1** - Check documentation and common issues
2. **Level 2** - Post in Discord community
3. **Level 3** - Create GitHub issue
4. **Level 4** - Contact support team
5. **Level 5** - Emergency escalation

## Conclusion

This troubleshooting guide covers the most common issues encountered with the LVR Auction Hook system. For additional help:

1. Check the documentation first
2. Search existing issues
3. Ask the community
4. Create a detailed issue report
5. Contact support if needed

Remember to:
- Provide detailed error messages
- Include relevant logs
- Describe steps to reproduce
- Mention your environment
- Be patient and helpful
