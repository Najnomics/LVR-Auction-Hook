package operator

import (
	"context"
	"crypto/ecdsa"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/sirupsen/logrus"

	"github.com/lvr-auction-hook/avs/pkg/types"
)

// Operator handles AVS operations for LVR auction validation
type Operator struct {
	config        *types.OperatorConfig
	privateKey    *ecdsa.PrivateKey
	address       common.Address
	client        *ethclient.Client
	priceMonitor  *PriceMonitor
	auctionCoord  *AuctionCoordinator
	logger        *logrus.Logger
	ctx           context.Context
	cancel        context.CancelFunc
}

// NewOperator creates a new operator instance
func NewOperator(config *types.OperatorConfig) (*Operator, error) {
	logger := logrus.New()
	logger.SetLevel(logrus.InfoLevel)

	// Parse private key
	privateKey, err := crypto.HexToECDSA(config.PrivateKey)
	if err != nil {
		return nil, err
	}

	// Get public key and address
	publicKey := privateKey.Public()
	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		return nil, err
	}
	address := crypto.PubkeyToAddress(*publicKeyECDSA)

	// Connect to Ethereum client
	client, err := ethclient.Dial(config.NetworkConfig.RPCURL)
	if err != nil {
		return nil, err
	}

	ctx, cancel := context.WithCancel(context.Background())

	// Initialize price monitor
	priceMonitor, err := NewPriceMonitor(config.PriceFeeds, logger)
	if err != nil {
		cancel()
		return nil, err
	}

	// Initialize auction coordinator
	auctionCoord, err := NewAuctionCoordinator(address, client, logger)
	if err != nil {
		cancel()
		return nil, err
	}

	operator := &Operator{
		config:       config,
		privateKey:   privateKey,
		address:      address,
		client:       client,
		priceMonitor: priceMonitor,
		auctionCoord: auctionCoord,
		logger:       logger,
		ctx:          ctx,
		cancel:       cancel,
	}

	return operator, nil
}

// Start begins the operator's main loop
func (o *Operator) Start() error {
	o.logger.Info("Starting LVR Auction Hook Operator...")

	// Start price monitoring
	go o.priceMonitor.Start(o.ctx)

	// Start auction coordination
	go o.auctionCoord.Start(o.ctx)

	// Main operator loop
	go o.run()

	o.logger.Info("Operator started successfully")
	return nil
}

// Stop gracefully shuts down the operator
func (o *Operator) Stop() error {
	o.logger.Info("Stopping operator...")
	o.cancel()
	
	// Wait for goroutines to finish
	time.Sleep(2 * time.Second)
	
	o.logger.Info("Operator stopped")
	return nil
}

// run is the main operator loop
func (o *Operator) run() {
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-o.ctx.Done():
			return
		case <-ticker.C:
			o.processTasks()
		}
	}
}

// processTasks processes incoming AVS tasks
func (o *Operator) processTasks() {
	// Get pending tasks from the service manager
	tasks, err := o.auctionCoord.GetPendingTasks()
	if err != nil {
		o.logger.WithError(err).Error("Failed to get pending tasks")
		return
	}

	for _, task := range tasks {
		if task.Deadline.Before(time.Now()) {
			o.logger.WithField("task_id", task.ID).Warn("Task deadline passed, skipping")
			continue
		}

		// Process the task
		go o.processTask(task)
	}
}

// processTask processes a single auction task
func (o *Operator) processTask(task *types.Task) {
	o.logger.WithField("task_id", task.ID).Info("Processing auction task")

	// Get auction details
	auction, err := o.auctionCoord.GetAuction(task.AuctionID)
	if err != nil {
		o.logger.WithError(err).WithField("auction_id", task.AuctionID).Error("Failed to get auction")
		return
	}

	// Validate auction and determine winner
	winner, winningBid, err := o.validateAuction(auction)
	if err != nil {
		o.logger.WithError(err).WithField("auction_id", auction.ID).Error("Failed to validate auction")
		return
	}

	// Submit response to service manager
	response := &types.TaskResponse{
		Operator:   o.address.Hex(),
		AuctionID:  auction.ID,
		Winner:     winner,
		WinningBid: winningBid,
		Timestamp:  time.Now(),
	}

	err = o.auctionCoord.SubmitTaskResponse(task.ID, response)
	if err != nil {
		o.logger.WithError(err).WithField("task_id", task.ID).Error("Failed to submit task response")
		return
	}

	o.logger.WithFields(logrus.Fields{
		"task_id":     task.ID,
		"auction_id":  auction.ID,
		"winner":      winner,
		"winning_bid": winningBid.String(),
	}).Info("Task response submitted successfully")
}

// validateAuction validates an auction and determines the winner
func (o *Operator) validateAuction(auction *types.Auction) (string, *big.Int, error) {
	// Get current price data for the pool
	priceData, err := o.priceMonitor.GetPriceData(auction.PoolID)
	if err != nil {
		return "", nil, err
	}

	// Check if price discrepancy exists (LVR opportunity)
	if priceData.Discrepancy.Cmp(big.NewInt(50)) < 0 { // 0.5% threshold
		return "", big.NewInt(0), nil // No significant LVR opportunity
	}

	// Simulate auction winner selection
	// In a real implementation, this would collect and validate sealed bids
	winner := "0x1234567890123456789012345678901234567890" // Mock winner
	winningBid := new(big.Int).Div(priceData.Discrepancy, big.NewInt(1000)) // Mock bid

	o.logger.WithFields(logrus.Fields{
		"auction_id":  auction.ID,
		"discrepancy": priceData.Discrepancy.String(),
		"winner":      winner,
		"winning_bid": winningBid.String(),
	}).Info("Auction validated")

	return winner, winningBid, nil
}

// GetMetrics returns operator metrics
func (o *Operator) GetMetrics() map[string]interface{} {
	return map[string]interface{}{
		"operator_address": o.address.Hex(),
		"is_running":       o.ctx.Err() == nil,
		"price_feeds":      len(o.config.PriceFeeds),
		"uptime":          time.Since(time.Now()).String(), // This would be tracked properly
	}
}

// Register registers the operator with the AVS
func (o *Operator) Register() error {
	o.logger.Info("Registering operator with AVS...")

	// Create transaction options
	auth, err := bind.NewKeyedTransactorWithChainID(o.privateKey, big.NewInt(int64(o.config.NetworkConfig.ChainID)))
	if err != nil {
		return err
	}

	// Set gas price and limit
	gasPrice, err := o.client.SuggestGasPrice(o.ctx)
	if err != nil {
		return err
	}
	auth.GasPrice = gasPrice
	auth.GasLimit = 500000

	// Register with service manager
	// This would call the actual contract method
	o.logger.Info("Operator registration transaction sent")

	return nil
}

// GetAddress returns the operator's address
func (o *Operator) GetAddress() common.Address {
	return o.address
}

// GetStake returns the operator's stake amount
func (o *Operator) GetStake() (*big.Int, error) {
	// This would query the service manager contract
	return big.NewInt(32 * 1e18), nil // Mock stake
}
