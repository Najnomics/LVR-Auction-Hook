package main

import (
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/sirupsen/logrus"
	"gopkg.in/yaml.v3"

	"github.com/lvr-auction-hook/avs/pkg/operator"
	"github.com/lvr-auction-hook/avs/pkg/types"
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

	// Create operator
	op, err := operator.NewOperator(config)
	if err != nil {
		logrus.Fatal("Failed to create operator:", err)
	}

	// Register operator with AVS
	err = op.Register()
	if err != nil {
		logrus.Fatal("Failed to register operator:", err)
	}

	// Start operator
	err = op.Start()
	if err != nil {
		logrus.Fatal("Failed to start operator:", err)
	}

	logrus.Info("LVR Auction Hook Operator is running...")
	logrus.Info("Operator Address:", op.GetAddress().Hex())

	// Wait for shutdown signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	logrus.Info("Shutdown signal received, stopping operator...")

	// Stop operator
	err = op.Stop()
	if err != nil {
		logrus.Error("Error stopping operator:", err)
		os.Exit(1)
	}

	logrus.Info("Operator stopped successfully")
}

func loadConfig(configFile string) (*types.OperatorConfig, error) {
	data, err := os.ReadFile(configFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	var config types.OperatorConfig
	err = yaml.Unmarshal(data, &config)
	if err != nil {
		return nil, fmt.Errorf("failed to parse config file: %w", err)
	}

	return &config, nil
}
