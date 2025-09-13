package types

import (
	"math/big"
	"time"
)

// Auction represents an auction for MEV rights
type Auction struct {
	ID          string    `json:"id"`
	PoolID      string    `json:"pool_id"`
	StartTime   time.Time `json:"start_time"`
	Duration    int64     `json:"duration"`
	IsActive    bool      `json:"is_active"`
	IsComplete  bool      `json:"is_complete"`
	Winner      string    `json:"winner"`
	WinningBid  *big.Int  `json:"winning_bid"`
	TotalBids   int       `json:"total_bids"`
	BlockNumber uint64    `json:"block_number"`
}

// Bid represents a sealed bid in an auction
type Bid struct {
	Bidder     string   `json:"bidder"`
	Amount     *big.Int `json:"amount"`
	Commitment string   `json:"commitment"`
	Revealed   bool     `json:"revealed"`
	Timestamp  time.Time `json:"timestamp"`
}

// PriceData represents price information from an oracle
type PriceData struct {
	Token0       string    `json:"token0"`
	Token1       string    `json:"token1"`
	Price        *big.Int  `json:"price"`
	Timestamp    time.Time `json:"timestamp"`
	Source       string    `json:"source"`
	IsStale      bool      `json:"is_stale"`
	Discrepancy  *big.Int  `json:"discrepancy"`
}

// Task represents an AVS task for auction validation
type Task struct {
	ID            uint32    `json:"id"`
	AuctionID     string    `json:"auction_id"`
	PoolID        string    `json:"pool_id"`
	CreatedBlock  uint32    `json:"created_block"`
	Deadline      time.Time `json:"deadline"`
	Completed     bool      `json:"completed"`
	Responses     []TaskResponse `json:"responses"`
}

// TaskResponse represents an operator's response to a task
type TaskResponse struct {
	Operator   string    `json:"operator"`
	AuctionID  string    `json:"auction_id"`
	Winner     string    `json:"winner"`
	WinningBid *big.Int  `json:"winning_bid"`
	Signature  string    `json:"signature"`
	Timestamp  time.Time `json:"timestamp"`
}

// Operator represents an AVS operator
type Operator struct {
	Address      string   `json:"address"`
	Stake        *big.Int `json:"stake"`
	Registered   bool     `json:"registered"`
	LastSeen     time.Time `json:"last_seen"`
	Accuracy     float64  `json:"accuracy"`
	TotalTasks   uint64   `json:"total_tasks"`
	SuccessfulTasks uint64 `json:"successful_tasks"`
}

// MEVDistribution represents MEV distribution to LPs
type MEVDistribution struct {
	PoolID          string   `json:"pool_id"`
	TotalAmount     *big.Int `json:"total_amount"`
	LPAmount        *big.Int `json:"lp_amount"`
	AVSAmount       *big.Int `json:"avs_amount"`
	ProtocolAmount  *big.Int `json:"protocol_amount"`
	GasAmount       *big.Int `json:"gas_amount"`
	BlockNumber     uint64   `json:"block_number"`
	Timestamp       time.Time `json:"timestamp"`
}

// LPReward represents rewards for liquidity providers
type LPReward struct {
	LPAddress       string   `json:"lp_address"`
	PoolID          string   `json:"pool_id"`
	LiquidityShare  *big.Int `json:"liquidity_share"`
	RewardAmount    *big.Int `json:"reward_amount"`
	ClaimedAmount   *big.Int `json:"claimed_amount"`
	LastClaimTime   time.Time `json:"last_claim_time"`
}

// AuctionMetrics represents metrics for auction performance
type AuctionMetrics struct {
	TotalAuctions       uint64    `json:"total_auctions"`
	SuccessfulAuctions  uint64    `json:"successful_auctions"`
	TotalMEVRecovered   *big.Int  `json:"total_mev_recovered"`
	AverageBidAmount    *big.Int  `json:"average_bid_amount"`
	AverageAuctionTime  float64   `json:"average_auction_time"`
	LPCompensationRate  float64   `json:"lp_compensation_rate"`
	LastUpdated         time.Time `json:"last_updated"`
}

// NetworkConfig represents network configuration
type NetworkConfig struct {
	ChainID           uint64 `json:"chain_id"`
	RPCURL            string `json:"rpc_url"`
	WSURL             string `json:"ws_url"`
	ContractAddresses map[string]string `json:"contract_addresses"`
	BlockConfirmations uint64 `json:"block_confirmations"`
}

// PriceFeedConfig represents price feed configuration
type PriceFeedConfig struct {
	Name       string `json:"name"`
	URL        string `json:"url"`
	APIKey     string `json:"api_key"`
	UpdateFreq int64  `json:"update_frequency_seconds"`
	Pairs      []TokenPair `json:"pairs"`
}

// TokenPair represents a trading pair
type TokenPair struct {
	Token0    string `json:"token0"`
	Token1    string `json:"token1"`
	Symbol    string `json:"symbol"`
	Decimals  int    `json:"decimals"`
	IsActive  bool   `json:"is_active"`
}

// OperatorConfig represents operator configuration
type OperatorConfig struct {
	PrivateKey     string            `json:"private_key"`
	Address        string            `json:"address"`
	StakeAmount    string            `json:"stake_amount"`
	ServiceManager string            `json:"service_manager"`
	NetworkConfig  NetworkConfig     `json:"network_config"`
	PriceFeeds     []PriceFeedConfig `json:"price_feeds"`
	LogLevel       string            `json:"log_level"`
	MetricsPort    int               `json:"metrics_port"`
}
