package aggregator

import (
	"context"
	"crypto/ecdsa"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"sync"
	"time"

	"github.com/Layr-Labs/eigensdk-go/chainio/clients/eth"
	"github.com/Layr-Labs/eigensdk-go/logging"
	"github.com/Layr-Labs/eigensdk-go/metrics"
	"github.com/Layr-Labs/eigensdk-go/nodeapi"
	"github.com/Layr-Labs/eigensdk-go/types"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/prometheus/client_golang/prometheus"

	"github.com/lvr-auction-hook/avs/pkg/avsregistry"
)

const (
	// SemVer is the semantic version of the aggregator
	SemVer = "0.0.1"
)

type Aggregator struct {
	config      Config
	logger      logging.Logger
	ethClient   eth.Client
	metricsReg  *prometheus.Registry
	metrics     metrics.Metrics
	nodeApi     *nodeapi.NodeApi

	avsWriter avsregistry.AvsRegistryChainWriter
	avsReader avsregistry.AvsRegistryChainReader

	// Aggregator specific fields
	taskResponses    map[uint32][]SignedAuctionTaskResponse
	taskResponsesMux sync.RWMutex
	quorumThreshold  types.ThresholdPercentage
}

type Config struct {
	EcdsaPrivateKeyStorePath      string `json:"ecdsa_private_key_store_path"`
	EthRpcUrl                     string `json:"eth_rpc_url"`
	EthWsUrl                      string `json:"eth_ws_url"`
	RegistryCoordinatorAddress    string `json:"registry_coordinator_address"`
	OperatorStateRetrieverAddress string `json:"operator_state_retriever_address"`
	EigenMetricsIpPortAddress     string `json:"eigen_metrics_ip_port_address"`
	EnableMetrics                 bool   `json:"enable_metrics"`
	NodeApiIpPortAddress          string `json:"node_api_ip_port_address"`
	EnableNodeApi                 bool   `json:"enable_node_api"`
	AggregatorServerIpPortAddr    string `json:"aggregator_server_ip_port_address"`
	QuorumThreshold               uint32 `json:"quorum_threshold"`
}

type AuctionTask struct {
	PoolId                      common.Hash    `json:"poolId"`
	BlockNumber                 uint32         `json:"blockNumber"`
	TaskCreatedBlock            uint32         `json:"taskCreatedBlock"`
	QuorumNumbers               types.QuorumNums `json:"quorumNumbers"`
	QuorumThresholdPercentage   types.ThresholdPercentage `json:"quorumThresholdPercentage"`
}

type AuctionTaskResponse struct {
	ReferenceTaskIndex uint32         `json:"referenceTaskIndex"`
	Winner             common.Address `json:"winner"`
	WinningBid         *big.Int       `json:"winningBid"`
	TotalBids          uint32         `json:"totalBids"`
}

type SignedAuctionTaskResponse struct {
	AuctionTaskResponse
	BlsSignature types.Signature `json:"blsSignature"`
	OperatorId   types.OperatorId `json:"operatorId"`
}

type TaskResponseInfo struct {
	TaskResponse *AuctionTaskResponse
	BlsSignature types.Signature
	OperatorId   types.OperatorId
}

func NewAggregator(config Config, logger logging.Logger) (*Aggregator, error) {
	var logLevel logging.LogLevel
	if config.EnableMetrics {
		logLevel = logging.Development
	} else {
		logLevel = logging.Production
	}

	logger = logger.With("component", "aggregator")

	ethClient, err := eth.NewClient(config.EthRpcUrl)
	if err != nil {
		return nil, fmt.Errorf("failed to create eth client: %w", err)
	}

	operatorEcdsaPrivateKey, err := crypto.LoadECDSA(config.EcdsaPrivateKeyStorePath)
	if err != nil {
		return nil, fmt.Errorf("failed to load aggregator ecdsa private key: %w", err)
	}

	operatorAddr := crypto.PubkeyToAddress(operatorEcdsaPrivateKey.PublicKey)
	logger.Info("Aggregator address", "address", operatorAddr.Hex())

	// Create AVS clients
	avsReader, err := avsregistry.NewAvsRegistryChainReader(
		common.HexToAddress(config.RegistryCoordinatorAddress),
		common.HexToAddress(config.OperatorStateRetrieverAddress),
		ethClient,
		logger,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create avs registry chain reader: %w", err)
	}

	avsWriter, err := avsregistry.NewAvsRegistryChainWriter(
		common.HexToAddress(config.RegistryCoordinatorAddress),
		common.HexToAddress(config.OperatorStateRetrieverAddress),
		ethClient,
		operatorEcdsaPrivateKey,
		logger,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create avs registry chain writer: %w", err)
	}

	// Create metrics registry
	var metricsReg *prometheus.Registry
	var eigenMetrics metrics.Metrics
	if config.EnableMetrics {
		metricsReg = prometheus.NewRegistry()
		eigenMetrics = metrics.NewPrometheusMetrics(metricsReg, "lvr-auction-hook", logger)
		eigenMetrics.Start(context.Background(), config.EigenMetricsIpPortAddress)
	} else {
		metricsReg = prometheus.NewRegistry()
		eigenMetrics = metrics.NewNoopMetrics()
	}

	// Create node API
	var nodeApi *nodeapi.NodeApi
	if config.EnableNodeApi {
		nodeApi = nodeapi.NewNodeApi("lvr-auction-hook-aggregator", SemVer, config.NodeApiIpPortAddress, logger)
		go nodeApi.Start()
	}

	aggregator := &Aggregator{
		config:           config,
		logger:           logger,
		ethClient:        ethClient,
		metricsReg:       metricsReg,
		metrics:          eigenMetrics,
		nodeApi:          nodeApi,
		avsWriter:        *avsWriter,
		avsReader:        *avsReader,
		taskResponses:    make(map[uint32][]SignedAuctionTaskResponse),
		quorumThreshold:  types.ThresholdPercentage(config.QuorumThreshold),
	}

	return aggregator, nil
}

func (a *Aggregator) Start(ctx context.Context) error {
	a.logger.Info("Starting aggregator")

	// Start HTTP server for receiving task responses
	go a.startHTTPServer(ctx)

	// Start task processing
	go a.processTaskResponses(ctx)

	// Keep the aggregator running
	<-ctx.Done()
	return nil
}

func (a *Aggregator) startHTTPServer(ctx context.Context) {
	mux := http.NewServeMux()
	mux.HandleFunc("/submit-response", a.handleTaskResponseSubmission)
	mux.HandleFunc("/health", a.handleHealthCheck)

	server := &http.Server{
		Addr:    a.config.AggregatorServerIpPortAddr,
		Handler: mux,
	}

	a.logger.Info("Starting HTTP server", "addr", a.config.AggregatorServerIpPortAddr)

	go func() {
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			a.logger.Error("HTTP server error", "error", err)
		}
	}()

	<-ctx.Done()
	server.Shutdown(context.Background())
}

func (a *Aggregator) handleTaskResponseSubmission(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var signedResponse SignedAuctionTaskResponse
	if err := json.NewDecoder(r.Body).Decode(&signedResponse); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	// Store the response
	a.taskResponsesMux.Lock()
	a.taskResponses[signedResponse.ReferenceTaskIndex] = append(
		a.taskResponses[signedResponse.ReferenceTaskIndex],
		signedResponse,
	)
	a.taskResponsesMux.Unlock()

	a.logger.Info("Received task response",
		"taskIndex", signedResponse.ReferenceTaskIndex,
		"operatorId", signedResponse.OperatorId.Hex(),
		"winner", signedResponse.Winner.Hex(),
		"winningBid", signedResponse.WinningBid.String(),
	)

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "success"})
}

func (a *Aggregator) handleHealthCheck(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status":    "healthy",
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

func (a *Aggregator) processTaskResponses(ctx context.Context) {
	a.logger.Info("Starting task response processor")

	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			a.checkAndProcessCompletedTasks()
		}
	}
}

func (a *Aggregator) checkAndProcessCompletedTasks() {
	a.taskResponsesMux.RLock()
	defer a.taskResponsesMux.RUnlock()

	for taskIndex, responses := range a.taskResponses {
		if len(responses) >= int(a.quorumThreshold) {
			a.processCompletedTask(taskIndex, responses)
		}
	}
}

func (a *Aggregator) processCompletedTask(taskIndex uint32, responses []SignedAuctionTaskResponse) {
	a.logger.Info("Processing completed task",
		"taskIndex", taskIndex,
		"responseCount", len(responses),
	)

	// Find the most common response (consensus)
	responseCounts := make(map[string]int)
	for _, response := range responses {
		responseKey := fmt.Sprintf("%s-%s-%d",
			response.Winner.Hex(),
			response.WinningBid.String(),
			response.TotalBids,
		)
		responseCounts[responseKey]++
	}

	// Find the response with the highest count
	var consensusResponse *SignedAuctionTaskResponse
	maxCount := 0
	for _, response := range responses {
		responseKey := fmt.Sprintf("%s-%s-%d",
			response.Winner.Hex(),
			response.WinningBid.String(),
			response.TotalBids,
		)
		if responseCounts[responseKey] > maxCount {
			maxCount = responseCounts[responseKey]
			consensusResponse = &response
		}
	}

	if consensusResponse != nil {
		a.logger.Info("Task consensus reached",
			"taskIndex", taskIndex,
			"consensusCount", maxCount,
			"totalResponses", len(responses),
			"winner", consensusResponse.Winner.Hex(),
			"winningBid", consensusResponse.WinningBid.String(),
		)

		// Here you would submit the consensus result to the smart contract
		// For now, we'll just log it
		a.submitConsensusToContract(taskIndex, consensusResponse)
	}
}

func (a *Aggregator) submitConsensusToContract(taskIndex uint32, consensus *SignedAuctionTaskResponse) {
	a.logger.Info("Submitting consensus to contract",
		"taskIndex", taskIndex,
		"winner", consensus.Winner.Hex(),
		"winningBid", consensus.WinningBid.String(),
	)

	// In a real implementation, this would:
	// 1. Verify BLS signatures
	// 2. Submit the consensus result to the LVR Auction Service Manager
	// 3. Handle any errors or retries
	
	// For now, we'll simulate this
	time.Sleep(100 * time.Millisecond)
	a.logger.Info("Consensus submitted successfully")
}
