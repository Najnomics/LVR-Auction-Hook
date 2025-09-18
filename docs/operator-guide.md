# LVR Auction Hook - Operator Guide

## Overview

This guide provides comprehensive instructions for operators participating in the LVR Auction Hook system. Operators play a crucial role in detecting MEV opportunities, coordinating auctions, and ensuring fair MEV redistribution to liquidity providers.

## Operator Responsibilities

### Core Tasks

1. **Price Monitoring**: Continuously monitor price discrepancies across DEXs
2. **Auction Coordination**: Manage sealed-bid auctions for MEV opportunities
3. **Auction Resolution**: Determine winners and distribute rewards
4. **Proceeds Distribution**: Ensure fair distribution to LPs

### Performance Metrics

- **Uptime**: 99.9% availability target
- **Response Time**: < 1 second for price discrepancy detection
- **Accuracy**: > 95% correct auction outcomes
- **Efficiency**: Minimal gas usage for operations

## Getting Started

### Prerequisites

- **Technical Knowledge**: Understanding of DeFi, MEV, and EigenLayer
- **Infrastructure**: Reliable server with high uptime
- **Capital**: Sufficient ETH for gas fees and potential slashing
- **Monitoring**: Real-time monitoring and alerting systems

### Initial Setup

1. **Install Dependencies**
   ```bash
   # Install Go
   go version  # Should be 1.21+

   # Install Foundry
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Clone Repository**
   ```bash
   git clone https://github.com/your-org/lvr-auction-hook
   cd lvr-auction-hook/avs-new
   ```

3. **Configure Environment**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

4. **Build and Test**
   ```bash
   # Build the performer
   go build -o lvr-auction-avs cmd/main.go

   # Run tests
   go test ./...
   ```

## Configuration

### Environment Variables

```bash
# Network Configuration
ETHEREUM_RPC_URL=https://mainnet.infura.io/v3/YOUR_KEY
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY

# EigenLayer Configuration
EIGENLAYER_ALLOCATION_MANAGER=0x...
EIGENLAYER_KEY_REGISTRAR=0x...
EIGENLAYER_PERMISSION_CONTROLLER=0x...

# LVR Auction Configuration
PRICE_DISCREPANCY_THRESHOLD_BPS=50
AUCTION_DURATION=8
LP_SHARE_PERCENTAGE=8500

# Operator Configuration
OPERATOR_PRIVATE_KEY=0x...
OPERATOR_NAME=your-operator-name
```

### AVS Configuration

```yaml
# lvr-auction-mainnet.yaml
avs:
  name: "LVR Auction AVS"
  version: "1.0.0"
  description: "MEV Protection for Uniswap V4"

serviceManager:
  address: "0x..."
  chainId: 1

taskHook:
  address: "0x..."
  chainId: 42161

operator:
  name: "your-operator-name"
  privateKey: "0x..."
  stakeAmount: "1.0" # ETH

monitoring:
  priceFeeds:
    - "chainlink"
    - "pyth"
    - "api3"
  thresholdBps: 50
  auctionDuration: 8

rewards:
  operatorShare: 0.15
  lpShare: 0.85
  slashingThreshold: 0.05
```

## Running the Operator

### Local Development

```bash
# Start local blockchain
anvil --fork-url $ETHEREUM_RPC_URL

# Deploy contracts
forge script script/DeployMyL1Contracts.s.sol --rpc-url http://localhost:8545 --broadcast
forge script script/DeployMyL2Contracts.s.sol --rpc-url http://localhost:8545 --broadcast

# Start operator
LVR_AUCTION_AVS_CONFIG_PATH=./specs/runtime/lvr-auction-devnet.yaml go run cmd/main.go
```

### Testnet Deployment

```bash
# Deploy to Sepolia
forge script script/DeployMyL1Contracts.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
forge script script/DeployMyL2Contracts.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

# Start operator
LVR_AUCTION_AVS_CONFIG_PATH=./specs/runtime/lvr-auction-testnet.yaml go run cmd/main.go
```

### Mainnet Deployment

```bash
# Deploy to mainnet
forge script script/DeployMyL1Contracts.s.sol --rpc-url $ETHEREUM_RPC_URL --broadcast --verify --slow
forge script script/DeployMyL2Contracts.s.sol --rpc-url $ETHEREUM_RPC_URL --broadcast --verify --slow

# Start operator
LVR_AUCTION_AVS_CONFIG_PATH=./specs/runtime/lvr-auction-mainnet.yaml go run cmd/main.go
```

## Docker Deployment

### Build Image

```bash
# Build Docker image
docker build -t lvr-auction-avs .

# Tag for registry
docker tag lvr-auction-avs your-registry/lvr-auction-avs:latest
```

### Run Container

```bash
# Run with environment file
docker run -d \
  --name lvr-auction-avs \
  --env-file .env \
  -p 8080:8080 \
  -p 8081:8081 \
  -p 9090:9090 \
  lvr-auction-avs

# Run with docker-compose
docker-compose up -d
```

### Docker Compose

```yaml
version: '3.8'
services:
  lvr-auction-avs:
    build: .
    container_name: lvr-auction-avs
    environment:
      - LVR_AUCTION_AVS_CONFIG_PATH=/app/config/lvr-auction-mainnet.yaml
    ports:
      - "8080:8080"
      - "8081:8081"
      - "9090:9090"
    volumes:
      - ./config:/app/config
      - ./logs:/app/logs
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8081/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

## Monitoring and Maintenance

### Health Checks

```bash
# Check operator health
curl http://localhost:8081/health

# Check metrics
curl http://localhost:9090/metrics

# Check logs
docker logs lvr-auction-avs
```

### Key Metrics

- **Uptime**: Operator availability percentage
- **Task Success Rate**: Successful task completion rate
- **Response Time**: Average response time for tasks
- **Gas Usage**: Gas efficiency metrics
- **Rewards**: Total rewards earned

### Alerting

Set up alerts for:

- **Downtime**: Operator offline for > 5 minutes
- **High Error Rate**: > 5% task failure rate
- **High Gas Usage**: Unusual gas consumption
- **Low Rewards**: Significant drop in rewards
- **Slashing Risk**: Approaching slashing threshold

## Task Management

### Price Monitoring Tasks

```go
type PriceMonitoringTask struct {
    PoolID        string    `json:"poolId"`
    TokenA        string    `json:"tokenA"`
    TokenB        string    `json:"tokenB"`
    DEXPrice      *big.Int  `json:"dexPrice"`
    CEXPrice      *big.Int  `json:"cexPrice"`
    Discrepancy   *big.Int  `json:"discrepancy"`
    Threshold     *big.Int  `json:"threshold"`
    Timestamp     int64     `json:"timestamp"`
}
```

**Responsibilities**:
- Monitor price feeds continuously
- Detect discrepancies above threshold
- Submit price discrepancy data
- Maintain data accuracy

### Auction Coordination Tasks

```go
type AuctionCoordinationTask struct {
    AuctionID     string    `json:"auctionId"`
    PoolID        string    `json:"poolId"`
    MEVAmount     *big.Int  `json:"mevAmount"`
    StartTime     int64     `json:"startTime"`
    EndTime       int64     `json:"endTime"`
    Bidders       []string  `json:"bidders"`
    Status        string    `json:"status"`
}
```

**Responsibilities**:
- Initiate sealed-bid auctions
- Manage bid collection
- Ensure fair auction process
- Handle auction timeouts

### Auction Resolution Tasks

```go
type AuctionResolutionTask struct {
    AuctionID     string    `json:"auctionId"`
    Winner        string    `json:"winner"`
    WinningBid    *big.Int  `json:"winningBid"`
    TotalBids     int       `json:"totalBids"`
    ResolutionTime int64    `json:"resolutionTime"`
    Status        string    `json:"status"`
}
```

**Responsibilities**:
- Determine auction winners
- Validate winning bids
- Process auction results
- Handle disputes

### Proceeds Distribution Tasks

```go
type ProceedsDistributionTask struct {
    AuctionID     string    `json:"auctionId"`
    TotalProceeds *big.Int  `json:"totalProceeds"`
    OperatorShare *big.Int  `json:"operatorShare"`
    LPShares      []LPShares `json:"lpShares"`
    DistributionTime int64  `json:"distributionTime"`
    Status        string    `json:"status"`
}
```

**Responsibilities**:
- Calculate reward distributions
- Execute reward transfers
- Ensure accurate distribution
- Maintain audit trail

## Best Practices

### Security

1. **Private Key Management**
   - Use hardware wallets for production
   - Implement key rotation policies
   - Monitor for unauthorized access

2. **Network Security**
   - Use secure RPC endpoints
   - Implement rate limiting
   - Monitor for unusual activity

3. **Code Security**
   - Keep dependencies updated
   - Regular security audits
   - Implement access controls

### Performance

1. **Resource Management**
   - Monitor CPU and memory usage
   - Implement resource limits
   - Optimize for efficiency

2. **Network Optimization**
   - Use multiple RPC endpoints
   - Implement connection pooling
   - Monitor latency

3. **Gas Optimization**
   - Optimize transaction batching
   - Use gas price optimization
   - Monitor gas usage patterns

### Reliability

1. **High Availability**
   - Implement redundancy
   - Use load balancing
   - Monitor uptime

2. **Error Handling**
   - Implement retry logic
   - Log all errors
   - Have recovery procedures

3. **Monitoring**
   - Real-time monitoring
   - Alerting systems
   - Performance tracking

## Troubleshooting

### Common Issues

1. **Connection Issues**
   ```bash
   # Check RPC connectivity
   curl -X POST -H "Content-Type: application/json" \
     --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
     $ETHEREUM_RPC_URL
   ```

2. **Task Failures**
   ```bash
   # Check task logs
   docker logs lvr-auction-avs | grep ERROR

   # Check task status
   curl http://localhost:8081/tasks/status
   ```

3. **Performance Issues**
   ```bash
   # Check resource usage
   docker stats lvr-auction-avs

   # Check metrics
   curl http://localhost:9090/metrics | grep performance
   ```

### Emergency Procedures

1. **Pause Operations**
   ```bash
   # Pause operator
   docker stop lvr-auction-avs

   # Pause contracts
   cast send $LVR_HOOK_ADDRESS "pause()" --rpc-url $ETHEREUM_RPC_URL --private-key $OPERATOR_PRIVATE_KEY
   ```

2. **Emergency Withdrawal**
   ```bash
   # Withdraw funds
   cast send $LVR_HOOK_ADDRESS "emergencyWithdraw()" --rpc-url $ETHEREUM_RPC_URL --private-key $OPERATOR_PRIVATE_KEY
   ```

3. **Recovery Procedures**
   ```bash
   # Restart operator
   docker restart lvr-auction-avs

   # Check health
   curl http://localhost:8081/health
   ```

## Support and Resources

### Documentation

- **Technical Docs**: `/docs/technical-specification.md`
- **API Reference**: `/docs/api-reference.md`
- **Deployment Guide**: `/docs/deployment-guide.md`

### Community

- **Discord**: [Discord Server]
- **GitHub**: [GitHub Repository]
- **Forum**: [Community Forum]

### Support

- **Technical Issues**: GitHub Issues
- **Emergency Support**: [Emergency Contact]
- **General Questions**: Discord Community

## Conclusion

Operating the LVR Auction Hook requires technical expertise, reliable infrastructure, and commitment to maintaining high performance. By following this guide and implementing best practices, operators can contribute to a more fair and efficient DeFi ecosystem while earning rewards for their services.

Remember to:
- Monitor system health continuously
- Maintain high uptime and performance
- Follow security best practices
- Participate in community discussions
- Keep up with updates and improvements
