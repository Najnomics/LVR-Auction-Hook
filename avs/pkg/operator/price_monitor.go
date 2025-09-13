package operator

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"sync"
	"time"

	"github.com/go-resty/resty/v2"
	"github.com/sirupsen/logrus"

	"github.com/lvr-auction-hook/avs/pkg/types"
)

// PriceMonitor monitors price feeds for LVR detection
type PriceMonitor struct {
	priceFeeds []types.PriceFeedConfig
	client     *resty.Client
	logger     *logrus.Logger
	cache      map[string]*types.PriceData
	mutex      sync.RWMutex
}

// NewPriceMonitor creates a new price monitor
func NewPriceMonitor(priceFeeds []types.PriceFeedConfig, logger *logrus.Logger) (*PriceMonitor, error) {
	client := resty.New()
	client.SetTimeout(10 * time.Second)

	return &PriceMonitor{
		priceFeeds: priceFeeds,
		client:     client,
		logger:     logger,
		cache:      make(map[string]*types.PriceData),
	}, nil
}

// Start begins price monitoring
func (pm *PriceMonitor) Start(ctx context.Context) {
	pm.logger.Info("Starting price monitoring...")

	// Start monitoring for each price feed
	for _, feed := range pm.priceFeeds {
		go pm.monitorFeed(ctx, feed)
	}

	// Start cache cleanup
	go pm.cleanupCache(ctx)
}

// monitorFeed monitors a specific price feed
func (pm *PriceMonitor) monitorFeed(ctx context.Context, feed types.PriceFeedConfig) {
	ticker := time.NewTicker(time.Duration(feed.UpdateFreq) * time.Second)
	defer ticker.Stop()

	pm.logger.WithField("feed", feed.Name).Info("Starting price feed monitoring")

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			pm.updatePrices(feed)
		}
	}
}

// updatePrices updates prices for a specific feed
func (pm *PriceMonitor) updatePrices(feed types.PriceFeedConfig) {
	for _, pair := range feed.Pairs {
		if !pair.IsActive {
			continue
		}

		priceData, err := pm.fetchPrice(feed, pair)
		if err != nil {
			pm.logger.WithError(err).WithFields(logrus.Fields{
				"feed":  feed.Name,
				"pair":  pair.Symbol,
			}).Error("Failed to fetch price")
			continue
		}

		pm.updateCache(pair.Token0, pair.Token1, priceData)
	}
}

// fetchPrice fetches price data from a specific feed
func (pm *PriceMonitor) fetchPrice(feed types.PriceFeedConfig, pair types.TokenPair) (*types.PriceData, error) {
	url := fmt.Sprintf("%s/price/%s", feed.URL, pair.Symbol)
	
	resp, err := pm.client.R().
		SetHeader("X-API-Key", feed.APIKey).
		Get(url)

	if err != nil {
		return nil, err
	}

	if resp.StatusCode() != http.StatusOK {
		return nil, fmt.Errorf("HTTP %d: %s", resp.StatusCode(), resp.String())
	}

	var priceResponse struct {
		Price     string `json:"price"`
		Timestamp int64  `json:"timestamp"`
		Source    string `json:"source"`
	}

	err = json.Unmarshal(resp.Body(), &priceResponse)
	if err != nil {
		return nil, err
	}

	price, ok := new(big.Int).SetString(priceResponse.Price, 10)
	if !ok {
		return nil, fmt.Errorf("invalid price format: %s", priceResponse.Price)
	}

	return &types.PriceData{
		Token0:    pair.Token0,
		Token1:    pair.Token1,
		Price:     price,
		Timestamp: time.Unix(priceResponse.Timestamp, 0),
		Source:    priceResponse.Source,
		IsStale:   time.Since(time.Unix(priceResponse.Timestamp, 0)) > 1*time.Hour,
	}, nil
}

// updateCache updates the price cache
func (pm *PriceMonitor) updateCache(token0, token1 string, priceData *types.PriceData) {
	pm.mutex.Lock()
	defer pm.mutex.Unlock()

	key := pm.getCacheKey(token0, token1)
	pm.cache[key] = priceData

	pm.logger.WithFields(logrus.Fields{
		"pair":       fmt.Sprintf("%s/%s", token0, token1),
		"price":      priceData.Price.String(),
		"source":     priceData.Source,
		"is_stale":   priceData.IsStale,
	}).Debug("Price updated in cache")
}

// GetPriceData retrieves price data for a token pair
func (pm *PriceMonitor) GetPriceData(poolID string) (*types.PriceData, error) {
	pm.mutex.RLock()
	defer pm.mutex.RUnlock()

	// Parse pool ID to extract token pair (simplified)
	token0, token1, err := pm.parsePoolID(poolID)
	if err != nil {
		return nil, err
	}

	key := pm.getCacheKey(token0, token1)
	priceData, exists := pm.cache[key]
	if !exists {
		return nil, fmt.Errorf("no price data available for pair %s/%s", token0, token1)
	}

	// Check if price is stale
	if priceData.IsStale {
		return nil, fmt.Errorf("price data is stale for pair %s/%s", token0, token1)
	}

	return priceData, nil
}

// GetPriceDiscrepancy calculates price discrepancy between sources
func (pm *PriceMonitor) GetPriceDiscrepancy(token0, token1 string) (*big.Int, error) {
	pm.mutex.RLock()
	defer pm.mutex.RUnlock()

	key := pm.getCacheKey(token0, token1)
	priceData, exists := pm.cache[key]
	if !exists {
		return nil, fmt.Errorf("no price data available")
	}

	// Calculate discrepancy (simplified - in reality would compare multiple sources)
	// For now, return a mock discrepancy
	discrepancy := new(big.Int).Div(priceData.Price, big.NewInt(1000)) // 0.1% mock discrepancy
	
	return discrepancy, nil
}

// cleanupCache periodically cleans up stale cache entries
func (pm *PriceMonitor) cleanupCache(ctx context.Context) {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			pm.mutex.Lock()
			cutoff := time.Now().Add(-1 * time.Hour)
			
			for key, priceData := range pm.cache {
				if priceData.Timestamp.Before(cutoff) {
					delete(pm.cache, key)
				}
			}
			
			pm.mutex.Unlock()
		}
	}
}

// getCacheKey generates a cache key for a token pair
func (pm *PriceMonitor) getCacheKey(token0, token1 string) string {
	if token0 < token1 {
		return fmt.Sprintf("%s_%s", token0, token1)
	}
	return fmt.Sprintf("%s_%s", token1, token0)
}

// parsePoolID parses a pool ID to extract token addresses (simplified)
func (pm *PriceMonitor) parsePoolID(poolID string) (string, string, error) {
	// This is a simplified implementation
	// In reality, you'd decode the pool ID properly
	return "0x1234567890123456789012345678901234567890", "0x0987654321098765432109876543210987654321", nil
}

// GetCacheSize returns the current cache size
func (pm *PriceMonitor) GetCacheSize() int {
	pm.mutex.RLock()
	defer pm.mutex.RUnlock()
	return len(pm.cache)
}

// GetAllPrices returns all cached prices
func (pm *PriceMonitor) GetAllPrices() map[string]*types.PriceData {
	pm.mutex.RLock()
	defer pm.mutex.RUnlock()
	
	result := make(map[string]*types.PriceData)
	for key, value := range pm.cache {
		result[key] = value
	}
	return result
}
