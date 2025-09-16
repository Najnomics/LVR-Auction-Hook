package main

import (
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"context"

	"github.com/Layr-Labs/eigensdk-go/logging"
	"github.com/sirupsen/logrus"
	"gopkg.in/yaml.v3"

	"github.com/Najnomics/LVR-Auction-Hook/avs/operator"
)

var (
	configFile = flag.String("config", "config/operator.yaml", "Path to configuration file")
	logLevel   = flag.String("log-level", "info", "Log level (debug, info, warn, error)")
)

func main() {
	flag.Parse()

	// Set log level
	level, err := logrus.ParseLevel(*logLevel)
	if err != nil {
		logrus.Fatal("Invalid log level:", err)
	}
	logrus.SetLevel(level)

	// Load configuration
	config, err := loadConfig(*configFile)
	if err != nil {
		logrus.Fatal("Failed to load configuration:", err)
	}

	// Create logger
	logger := logging.NewNoopLogger() // Use noop logger for now

	// Create operator
	op, err := operator.NewOperator(*config, logger)
	if err != nil {
		logger.Fatal("Failed to create operator:", err)
	}

	// Start operator
	ctx := context.Background()
	err = op.Start(ctx)
	if err != nil {
		logger.Fatal("Failed to start operator:", err)
	}

	logger.Info("LVR Auction Hook Operator is running...")
	logger.Info("Operator Address:", op.GetOperatorAddress().Hex())

	// Wait for shutdown signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	logrus.Info("Shutdown signal received, stopping operator...")

	// Stop operator
	// The operator will stop when context is cancelled
	logger.Info("Operator stopped successfully")
}

func loadConfig(configFile string) (*operator.Config, error) {
	data, err := os.ReadFile(configFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	var config operator.Config
	err = yaml.Unmarshal(data, &config)
	if err != nil {
		return nil, fmt.Errorf("failed to parse config file: %w", err)
	}

	return &config, nil
}
