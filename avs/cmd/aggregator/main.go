package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/Layr-Labs/eigensdk-go/logging"
	"github.com/lvr-auction-hook/avs/aggregator"
)

var (
	configPath = flag.String("config", "config/aggregator.yaml", "Path to the config file")
)

func main() {
	flag.Parse()

	// Create logger
	logger, err := logging.NewZapLogger(logging.Development)
	if err != nil {
		panic(fmt.Sprintf("Failed to create logger: %v", err))
	}

	// Load config
	config, err := loadConfig(*configPath)
	if err != nil {
		logger.Fatal("Failed to load config", "error", err)
	}

	// Create aggregator
	agg, err := aggregator.NewAggregator(config, logger)
	if err != nil {
		logger.Fatal("Failed to create aggregator", "error", err)
	}

	// Create context that can be cancelled
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle shutdown signals
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		sig := <-sigChan
		logger.Info("Received shutdown signal", "signal", sig)
		cancel()
	}()

	// Start aggregator
	logger.Info("Starting LVR Auction Hook Aggregator")
	if err := agg.Start(ctx); err != nil {
		logger.Fatal("Aggregator failed", "error", err)
	}

	logger.Info("Aggregator stopped")
}

func loadConfig(path string) (aggregator.Config, error) {
	// For now, return a default config
	// In a real implementation, you would load from YAML/JSON
	return aggregator.Config{
		EcdsaPrivateKeyStorePath:      "keys/aggregator.ecdsa.key.json",
		EthRpcUrl:                     "http://localhost:8545",
		EthWsUrl:                      "ws://localhost:8546",
		RegistryCoordinatorAddress:    "0x0000000000000000000000000000000000000000",
		OperatorStateRetrieverAddress: "0x0000000000000000000000000000000000000000",
		EigenMetricsIpPortAddress:     "0.0.0.0:9091",
		EnableMetrics:                 true,
		NodeApiIpPortAddress:          "0.0.0.0:8080",
		EnableNodeApi:                 true,
		AggregatorServerIpPortAddr:    "0.0.0.0:9090",
		QuorumThreshold:               67, // 67% threshold
	}, nil
}
