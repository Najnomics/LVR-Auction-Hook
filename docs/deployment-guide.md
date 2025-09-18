# LVR Auction Hook - Deployment Guide

## Prerequisites

### Required Software

- **Foundry**: `curl -L https://foundry.paradigm.xyz | bash && foundryup`
- **Go**: Version 1.21+ for AVS components
- **Node.js**: Version 18+ for frontend components
- **Docker**: For containerized deployment

### Required Accounts

- **Deployer Account**: For contract deployment
- **Operator Account**: For AVS operation
- **API Keys**: CEX APIs, Etherscan, Infura/Alchemy

## Environment Setup

### 1. Clone Repository

```bash
git clone https://github.com/your-org/lvr-auction-hook
cd lvr-auction-hook
```

### 2. Install Dependencies

```bash
# Install Foundry dependencies
forge install

# Install Go dependencies
cd avs-new && go mod download

# Install Node.js dependencies
cd frontend && npm install
```

### 3. Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit configuration
nano .env
```

### 4. Set Up Wallets

```bash
# Generate deployer key
cast wallet new

# Generate operator key
cast wallet new

# Fund accounts (testnet)
cast send --rpc-url $SEPOLIA_RPC_URL --value 1ether $DEPLOYER_ADDRESS
```

## Local Development

### 1. Start Local Blockchain

```bash
# Start Anvil
anvil --fork-url $ETHEREUM_RPC_URL

# Or use make command
make start-anvil
```

### 2. Deploy Contracts

```bash
# Deploy main contracts
forge script script/DeployLVR.s.sol --rpc-url http://localhost:8545 --broadcast

# Deploy AVS contracts
cd avs-new/contracts
forge script script/DeployMyL1Contracts.s.sol --rpc-url http://localhost:8545 --broadcast
forge script script/DeployMyL2Contracts.s.sol --rpc-url http://localhost:8545 --broadcast
```

### 3. Start AVS Performer

```bash
# Start AVS performer
cd avs-new
go run cmd/main.go

# Or use Docker
docker build -t lvr-auction-avs .
docker run -d --name lvr-auction-avs lvr-auction-avs
```

## Testnet Deployment

### 1. Sepolia Deployment

```bash
# Deploy main contracts
forge script script/DeployLVR.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY

# Deploy AVS contracts
cd avs-new/contracts
forge script script/DeployMyL1Contracts.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY

forge script script/DeployMyL2Contracts.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### 2. Verify Contracts

```bash
# Verify main contracts
forge verify-contract --chain-id 11155111 --num-of-optimizations 200 --watch \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  $CONTRACT_ADDRESS src/hooks/LVRAuctionHook.sol:LVRAuctionHook

# Verify AVS contracts
forge verify-contract --chain-id 11155111 --num-of-optimizations 200 --watch \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  $AVS_CONTRACT_ADDRESS contracts/src/l1-contracts/LVRAuctionServiceManager.sol:LVRAuctionServiceManager
```

### 3. Configure AVS

```bash
# Set up operator
cd avs-new
LVR_AUCTION_AVS_CONFIG_PATH=./specs/runtime/lvr-auction-testnet.yaml go run cmd/main.go
```

## Mainnet Deployment

### 1. Pre-deployment Checklist

- [ ] All tests passing
- [ ] Security audit completed
- [ ] Gas optimization verified
- [ ] Environment variables configured
- [ ] Deployer account funded
- [ ] Emergency procedures documented

### 2. Deploy Contracts

```bash
# Deploy main contracts
forge script script/DeployLVR.s.sol \
  --rpc-url $ETHEREUM_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --slow

# Deploy AVS contracts
cd avs-new/contracts
forge script script/DeployMyL1Contracts.s.sol \
  --rpc-url $ETHEREUM_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --slow

forge script script/DeployMyL2Contracts.s.sol \
  --rpc-url $ETHEREUM_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --slow
```

### 3. Post-deployment Configuration

```bash
# Initialize contracts
cast send $LVR_HOOK_ADDRESS "initialize(address)" $AVS_SERVICE_MANAGER_ADDRESS \
  --rpc-url $ETHEREUM_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY

# Enable auctions for major pools
cast send $LVR_HOOK_ADDRESS "enableAuctionForPool(bytes32,bool)" $POOL_ID true \
  --rpc-url $ETHEREUM_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY
```

## Docker Deployment

### 1. Build Images

```bash
# Build main application
docker build -t lvr-auction-hook .

# Build AVS performer
cd avs-new
docker build -t lvr-auction-avs .
```

### 2. Run Containers

```bash
# Run AVS performer
docker run -d \
  --name lvr-auction-avs \
  -p 8080:8080 \
  -p 8081:8081 \
  -p 9090:9090 \
  -e LVR_AUCTION_AVS_CONFIG_PATH=/app/config/lvr-auction-mainnet.yaml \
  lvr-auction-avs

# Run with docker-compose
docker-compose up -d
```

### 3. Monitor Deployment

```bash
# Check container status
docker ps

# View logs
docker logs lvr-auction-avs

# Check health
curl http://localhost:8081/health
```

## Monitoring and Maintenance

### 1. Health Checks

```bash
# Check AVS health
curl http://localhost:8081/health

# Check metrics
curl http://localhost:9090/metrics

# Check contract status
cast call $LVR_HOOK_ADDRESS "isActive()" --rpc-url $ETHEREUM_RPC_URL
```

### 2. Log Monitoring

```bash
# View real-time logs
docker logs -f lvr-auction-avs

# Filter error logs
docker logs lvr-auction-avs 2>&1 | grep ERROR

# Export logs
docker logs lvr-auction-avs > avs-logs.txt
```

### 3. Performance Monitoring

```bash
# Check auction performance
cast call $LVR_HOOK_ADDRESS "getAuctionStats()" --rpc-url $ETHEREUM_RPC_URL

# Check MEV distribution
cast call $LVR_HOOK_ADDRESS "getTotalMEVDistributed()" --rpc-url $ETHEREUM_RPC_URL

# Check operator performance
curl http://localhost:9090/metrics | grep operator_performance
```

## Troubleshooting

### Common Issues

1. **Deployment Failures**
   - Check gas limits and prices
   - Verify contract addresses
   - Ensure sufficient ETH balance

2. **AVS Connection Issues**
   - Verify RPC endpoints
   - Check operator configuration
   - Validate contract addresses

3. **Auction Failures**
   - Check price feed connectivity
   - Verify threshold settings
   - Monitor operator performance

### Emergency Procedures

1. **Pause System**
   ```bash
   cast send $LVR_HOOK_ADDRESS "pause()" --rpc-url $ETHEREUM_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY
   ```

2. **Emergency Withdrawal**
   ```bash
   cast send $LVR_HOOK_ADDRESS "emergencyWithdraw()" --rpc-url $ETHEREUM_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY
   ```

3. **Update Configuration**
   ```bash
   cast send $LVR_HOOK_ADDRESS "updateConfig(bytes)" $NEW_CONFIG --rpc-url $ETHEREUM_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY
   ```

## Security Considerations

### Pre-deployment

- [ ] Code audit completed
- [ ] Penetration testing performed
- [ ] Access controls verified
- [ ] Emergency procedures tested

### Post-deployment

- [ ] Monitor for unusual activity
- [ ] Regular security updates
- [ ] Operator performance monitoring
- [ ] Incident response plan ready

## Support and Maintenance

### Regular Maintenance

- **Daily**: Monitor system health and performance
- **Weekly**: Review operator performance and rewards
- **Monthly**: Update dependencies and security patches
- **Quarterly**: Comprehensive security review

### Support Channels

- **GitHub Issues**: Bug reports and feature requests
- **Discord**: Community support and discussions
- **Email**: Security issues and critical support
