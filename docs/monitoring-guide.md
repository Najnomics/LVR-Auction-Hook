# LVR Auction Hook - Monitoring Guide

## Overview

This guide provides comprehensive instructions for monitoring the LVR Auction Hook system, including health checks, metrics collection, alerting, and performance monitoring.

## Monitoring Architecture

### Components

- **Health Checks** - System health and availability monitoring
- **Metrics Collection** - Performance and operational metrics
- **Logging** - Structured logging and log aggregation
- **Alerting** - Automated alerts for critical issues
- **Dashboards** - Real-time monitoring dashboards

### Monitoring Stack

- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization and dashboards
- **ELK Stack** - Log aggregation and analysis
- **AlertManager** - Alert management and routing
- **Custom Health Checks** - Application-specific monitoring

## Health Checks

### Basic Health Check

#### Endpoint: `GET /health`

**Response:**
```json
{
  "status": "healthy",
  "timestamp": 1640995200,
  "version": "1.0.0",
  "uptime": 3600,
  "services": {
    "rpc": "healthy",
    "database": "healthy",
    "monitoring": "healthy"
  }
}
```

**Implementation:**
```go
func (w *LVRAuctionTaskWorker) healthCheck() HealthStatus {
    status := HealthStatus{
        Status:    "healthy",
        Timestamp: time.Now().Unix(),
        Version:   "1.0.0",
        Uptime:    w.getUptime(),
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
    
    // Check monitoring
    if err := w.checkMonitoring(); err != nil {
        status.Services["monitoring"] = "unhealthy"
        status.Status = "unhealthy"
    } else {
        status.Services["monitoring"] = "healthy"
    }
    
    return status
}
```

### Detailed Health Check

#### Endpoint: `GET /health/detailed`

**Response:**
```json
{
  "status": "healthy",
  "timestamp": 1640995200,
  "version": "1.0.0",
  "uptime": 3600,
  "services": {
    "rpc": {
      "status": "healthy",
      "response_time": 150,
      "last_check": 1640995200
    },
    "database": {
      "status": "healthy",
      "connection_count": 5,
      "last_check": 1640995200
    },
    "monitoring": {
      "status": "healthy",
      "metrics_count": 1000,
      "last_check": 1640995200
    }
  },
  "performance": {
    "cpu_usage": 45.2,
    "memory_usage": 67.8,
    "task_count": 150,
    "error_rate": 0.02
  }
}
```

### Custom Health Checks

#### RPC Health Check

```go
func (w *LVRAuctionTaskWorker) checkRPC() error {
    // Test basic connectivity
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()
    
    // Get latest block
    blockNumber, err := w.ethClient.BlockNumber(ctx)
    if err != nil {
        return fmt.Errorf("RPC connection failed: %w", err)
    }
    
    // Check if block is recent (within 5 minutes)
    if time.Since(time.Unix(int64(blockNumber), 0)) > 5*time.Minute {
        return fmt.Errorf("RPC block is stale")
    }
    
    return nil
}
```

#### Database Health Check

```go
func (w *LVRAuctionTaskWorker) checkDatabase() error {
    // Test database connection
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()
    
    // Simple query test
    var count int
    err := w.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM tasks").Scan(&count)
    if err != nil {
        return fmt.Errorf("database connection failed: %w", err)
    }
    
    return nil
}
```

#### Monitoring Health Check

```go
func (w *LVRAuctionTaskWorker) checkMonitoring() error {
    // Check if metrics collection is working
    if w.metricsStore == nil {
        return fmt.Errorf("metrics store not initialized")
    }
    
    // Check if recent metrics are available
    latest, err := w.metricsStore.GetLatest()
    if err != nil {
        return fmt.Errorf("no recent metrics available: %w", err)
    }
    
    // Check if metrics are recent (within 1 minute)
    if time.Since(latest.Timestamp) > 1*time.Minute {
        return fmt.Errorf("metrics are stale")
    }
    
    return nil
}
```

## Metrics Collection

### Prometheus Metrics

#### Endpoint: `GET /metrics`

**Response:**
```
# HELP lvr_auction_tasks_total Total number of tasks processed
# TYPE lvr_auction_tasks_total counter
lvr_auction_tasks_total{status="success"} 100
lvr_auction_tasks_total{status="failed"} 5

# HELP lvr_auction_auctions_total Total number of auctions created
# TYPE lvr_auction_auctions_total counter
lvr_auction_auctions_total 50

# HELP lvr_auction_rewards_total Total rewards distributed
# TYPE lvr_auction_rewards_total counter
lvr_auction_rewards_total 1000.5

# HELP lvr_auction_response_time_seconds Response time for operations
# TYPE lvr_auction_response_time_seconds histogram
lvr_auction_response_time_seconds_bucket{le="0.1"} 10
lvr_auction_response_time_seconds_bucket{le="0.5"} 50
lvr_auction_response_time_seconds_bucket{le="1.0"} 80
lvr_auction_response_time_seconds_bucket{le="+Inf"} 100

# HELP lvr_auction_system_info System information
# TYPE lvr_auction_system_info gauge
lvr_auction_system_info{version="1.0.0",environment="production"} 1
```

#### Implementation

```go
func (w *LVRAuctionTaskWorker) setupMetrics() {
    // Task metrics
    w.taskCounter = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "lvr_auction_tasks_total",
            Help: "Total number of tasks processed",
        },
        []string{"status"},
    )
    
    // Auction metrics
    w.auctionCounter = prometheus.NewCounter(
        prometheus.CounterOpts{
            Name: "lvr_auction_auctions_total",
            Help: "Total number of auctions created",
        },
    )
    
    // Reward metrics
    w.rewardCounter = prometheus.NewCounter(
        prometheus.CounterOpts{
            Name: "lvr_auction_rewards_total",
            Help: "Total rewards distributed",
        },
    )
    
    // Response time metrics
    w.responseTimeHistogram = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "lvr_auction_response_time_seconds",
            Help: "Response time for operations",
            Buckets: prometheus.DefBuckets,
        },
        []string{"operation"},
    )
    
    // System info
    w.systemInfo = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "lvr_auction_system_info",
            Help: "System information",
        },
        []string{"version", "environment"},
    )
    
    // Register metrics
    prometheus.MustRegister(
        w.taskCounter,
        w.auctionCounter,
        w.rewardCounter,
        w.responseTimeHistogram,
        w.systemInfo,
    )
}
```

### Custom Metrics

#### Task Processing Metrics

```go
func (w *LVRAuctionTaskWorker) recordTaskMetrics(task *Task, duration time.Duration, err error) {
    // Record task count
    status := "success"
    if err != nil {
        status = "failed"
    }
    w.taskCounter.WithLabelValues(status).Inc()
    
    // Record response time
    w.responseTimeHistogram.WithLabelValues("task_processing").Observe(duration.Seconds())
    
    // Record task type metrics
    w.taskCounter.WithLabelValues(fmt.Sprintf("task_type_%s", task.Type)).Inc()
}
```

#### Auction Metrics

```go
func (w *LVRAuctionTaskWorker) recordAuctionMetrics(auction *Auction) {
    // Record auction creation
    w.auctionCounter.Inc()
    
    // Record auction value
    w.rewardCounter.Add(float64(auction.MEVAmount))
    
    // Record auction duration
    duration := time.Duration(auction.EndTime - auction.StartTime)
    w.responseTimeHistogram.WithLabelValues("auction_duration").Observe(duration.Seconds())
}
```

#### System Metrics

```go
func (w *LVRAuctionTaskWorker) recordSystemMetrics() {
    // Record system info
    w.systemInfo.WithLabelValues("1.0.0", "production").Set(1)
    
    // Record CPU usage
    cpuUsage := w.getCPUUsage()
    w.systemInfo.WithLabelValues("cpu_usage", "percent").Set(cpuUsage)
    
    // Record memory usage
    memoryUsage := w.getMemoryUsage()
    w.systemInfo.WithLabelValues("memory_usage", "percent").Set(memoryUsage)
}
```

## Logging

### Structured Logging

#### Log Format

```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "level": "info",
  "message": "Task processing completed",
  "task_id": "0x123...",
  "task_type": "price_monitoring",
  "duration": 1.5,
  "status": "success",
  "operator": "0x456...",
  "auction_id": "0x789..."
}
```

#### Implementation

```go
func (w *LVRAuctionTaskWorker) setupLogging() {
    w.logger = logrus.New()
    w.logger.SetFormatter(&logrus.JSONFormatter{
        TimestampFormat: time.RFC3339,
        FieldMap: logrus.FieldMap{
            logrus.FieldKeyTime: "timestamp",
            logrus.FieldKeyLevel: "level",
            logrus.FieldKeyMsg: "message",
        },
    })
    
    w.logger.SetLevel(logrus.InfoLevel)
}

func (w *LVRAuctionTaskWorker) logTaskProcessing(task *Task, duration time.Duration, err error) {
    fields := logrus.Fields{
        "task_id": task.ID,
        "task_type": task.Type,
        "duration": duration.Seconds(),
        "operator": w.operatorAddress,
    }
    
    if err != nil {
        fields["status"] = "failed"
        fields["error"] = err.Error()
        w.logger.WithFields(fields).Error("Task processing failed")
    } else {
        fields["status"] = "success"
        w.logger.WithFields(fields).Info("Task processing completed")
    }
}
```

### Log Levels

#### Debug Level

```go
func (w *LVRAuctionTaskWorker) debugLog(message string, fields logrus.Fields) {
    w.logger.WithFields(fields).Debug(message)
}

// Usage
w.debugLog("Processing task", logrus.Fields{
    "task_id": task.ID,
    "task_type": task.Type,
})
```

#### Info Level

```go
func (w *LVRAuctionTaskWorker) infoLog(message string, fields logrus.Fields) {
    w.logger.WithFields(fields).Info(message)
}

// Usage
w.infoLog("Task completed", logrus.Fields{
    "task_id": task.ID,
    "duration": duration.Seconds(),
})
```

#### Warn Level

```go
func (w *LVRAuctionTaskWorker) warnLog(message string, fields logrus.Fields) {
    w.logger.WithFields(fields).Warn(message)
}

// Usage
w.warnLog("High error rate detected", logrus.Fields{
    "error_rate": errorRate,
    "threshold": 0.05,
})
```

#### Error Level

```go
func (w *LVRAuctionTaskWorker) errorLog(message string, fields logrus.Fields, err error) {
    fields["error"] = err.Error()
    w.logger.WithFields(fields).Error(message)
}

// Usage
w.errorLog("Task processing failed", logrus.Fields{
    "task_id": task.ID,
}, err)
```

## Alerting

### Alert Rules

#### High Error Rate Alert

```yaml
# alert-rules.yml
groups:
  - name: lvr_auction_alerts
    rules:
      - alert: HighErrorRate
        expr: rate(lvr_auction_tasks_total{status="failed"}[5m]) > 0.05
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} errors per second"
      
      - alert: SystemDown
        expr: up{job="lvr-auction-avs"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "LVR Auction AVS is down"
          description: "The LVR Auction AVS has been down for more than 1 minute"
      
      - alert: HighResponseTime
        expr: histogram_quantile(0.95, rate(lvr_auction_response_time_seconds_bucket[5m])) > 5
        for: 3m
        labels:
          severity: warning
        annotations:
          summary: "High response time detected"
          description: "95th percentile response time is {{ $value }} seconds"
```

#### Alert Manager Configuration

```yaml
# alertmanager.yml
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@lvr-auction.com'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
  - name: 'web.hook'
    webhook_configs:
      - url: 'http://localhost:5001/'
        send_resolved: true

  - name: 'email'
    email_configs:
      - to: 'admin@lvr-auction.com'
        subject: 'LVR Auction Alert: {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          {{ end }}
```

### Custom Alerts

#### Task Processing Alerts

```go
func (w *LVRAuctionTaskWorker) checkTaskAlerts() {
    // Check error rate
    errorRate := w.getErrorRate()
    if errorRate > 0.05 {
        w.sendAlert("high_error_rate", map[string]interface{}{
            "error_rate": errorRate,
            "threshold": 0.05,
        })
    }
    
    // Check response time
    avgResponseTime := w.getAverageResponseTime()
    if avgResponseTime > 5*time.Second {
        w.sendAlert("high_response_time", map[string]interface{}{
            "response_time": avgResponseTime.Seconds(),
            "threshold": 5.0,
        })
    }
    
    // Check task queue
    queueSize := w.getTaskQueueSize()
    if queueSize > 100 {
        w.sendAlert("large_task_queue", map[string]interface{}{
            "queue_size": queueSize,
            "threshold": 100,
        })
    }
}
```

#### System Alerts

```go
func (w *LVRAuctionTaskWorker) checkSystemAlerts() {
    // Check CPU usage
    cpuUsage := w.getCPUUsage()
    if cpuUsage > 80 {
        w.sendAlert("high_cpu_usage", map[string]interface{}{
            "cpu_usage": cpuUsage,
            "threshold": 80,
        })
    }
    
    // Check memory usage
    memoryUsage := w.getMemoryUsage()
    if memoryUsage > 90 {
        w.sendAlert("high_memory_usage", map[string]interface{}{
            "memory_usage": memoryUsage,
            "threshold": 90,
        })
    }
    
    // Check disk usage
    diskUsage := w.getDiskUsage()
    if diskUsage > 85 {
        w.sendAlert("high_disk_usage", map[string]interface{}{
            "disk_usage": diskUsage,
            "threshold": 85,
        })
    }
}
```

## Dashboards

### Grafana Dashboard

#### System Overview Dashboard

```json
{
  "dashboard": {
    "title": "LVR Auction Hook - System Overview",
    "panels": [
      {
        "title": "System Health",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=\"lvr-auction-avs\"}",
            "legendFormat": "System Status"
          }
        ]
      },
      {
        "title": "Task Processing Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(lvr_auction_tasks_total[5m])",
            "legendFormat": "Tasks/sec"
          }
        ]
      },
      {
        "title": "Error Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(lvr_auction_tasks_total{status=\"failed\"}[5m])",
            "legendFormat": "Errors/sec"
          }
        ]
      },
      {
        "title": "Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(lvr_auction_response_time_seconds_bucket[5m]))",
            "legendFormat": "95th percentile"
          }
        ]
      }
    ]
  }
}
```

#### Performance Dashboard

```json
{
  "dashboard": {
    "title": "LVR Auction Hook - Performance",
    "panels": [
      {
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "lvr_auction_system_info{label=\"cpu_usage\"}",
            "legendFormat": "CPU %"
          }
        ]
      },
      {
        "title": "Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "lvr_auction_system_info{label=\"memory_usage\"}",
            "legendFormat": "Memory %"
          }
        ]
      },
      {
        "title": "Task Queue Size",
        "type": "graph",
        "targets": [
          {
            "expr": "lvr_auction_task_queue_size",
            "legendFormat": "Queue Size"
          }
        ]
      }
    ]
  }
}
```

### Custom Dashboards

#### Real-time Monitoring

```go
func (w *LVRAuctionTaskWorker) setupRealTimeMonitoring() {
    // WebSocket for real-time updates
    http.HandleFunc("/ws", w.handleWebSocket)
    
    // Real-time metrics endpoint
    http.HandleFunc("/metrics/realtime", w.handleRealTimeMetrics)
}

func (w *LVRAuctionTaskWorker) handleRealTimeMetrics(w http.ResponseWriter, r *http.Request) {
    metrics := RealTimeMetrics{
        Timestamp:     time.Now().Unix(),
        TaskCount:     w.getTaskCount(),
        ErrorRate:     w.getErrorRate(),
        ResponseTime:  w.getAverageResponseTime().Seconds(),
        CPUUsage:      w.getCPUUsage(),
        MemoryUsage:   w.getMemoryUsage(),
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(metrics)
}
```

## Monitoring Setup

### Docker Compose

```yaml
# docker-compose.monitoring.yml
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./alert-rules.yml:/etc/prometheus/alert-rules.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-storage:/var/lib/grafana
      - ./grafana/dashboards:/var/lib/grafana/dashboards
      - ./grafana/provisioning:/etc/grafana/provisioning

  alertmanager:
    image: prom/alertmanager:latest
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'

  lvr-auction-avs:
    build: .
    ports:
      - "8080:8080"
      - "8081:8081"
      - "9090:9090"
    environment:
      - LVR_AUCTION_AVS_CONFIG_PATH=/app/config/lvr-auction-mainnet.yaml
    volumes:
      - ./config:/app/config
      - ./logs:/app/logs

volumes:
  grafana-storage:
```

### Prometheus Configuration

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert-rules.yml"

scrape_configs:
  - job_name: 'lvr-auction-avs'
    static_configs:
      - targets: ['lvr-auction-avs:9090']
    scrape_interval: 5s
    metrics_path: /metrics

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
```

## Best Practices

### Monitoring Best Practices

1. **Set up comprehensive monitoring** - Monitor all critical components
2. **Use structured logging** - Implement consistent log formats
3. **Implement alerting** - Set up alerts for critical issues
4. **Regular health checks** - Monitor system health continuously
5. **Performance tracking** - Track key performance metrics

### Alerting Best Practices

1. **Set appropriate thresholds** - Avoid alert fatigue
2. **Use escalation policies** - Implement proper escalation
3. **Test alerts regularly** - Ensure alerts work correctly
4. **Document alert procedures** - Provide clear response procedures
5. **Monitor alert effectiveness** - Track alert response times

### Logging Best Practices

1. **Use structured logging** - Implement consistent log formats
2. **Include context** - Add relevant context to logs
3. **Set appropriate log levels** - Use appropriate log levels
4. **Rotate logs** - Implement log rotation
5. **Secure sensitive data** - Avoid logging sensitive information

## Conclusion

This monitoring guide provides comprehensive instructions for monitoring the LVR Auction Hook system. By following these practices:

- **Ensure system reliability** - Monitor all critical components
- **Detect issues early** - Implement proactive monitoring
- **Respond quickly** - Set up effective alerting
- **Maintain performance** - Track key performance metrics
- **Improve continuously** - Use monitoring data for improvements

Remember to:
- Monitor all critical components
- Set up appropriate alerts
- Use structured logging
- Regular health checks
- Performance tracking
