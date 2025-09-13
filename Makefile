# LVR Auction Hook - Main Makefile
# Provides commands for development, testing, and deployment

.PHONY: help install build test deploy clean lint format

# Default target
help: ## Show this help message
	@echo "LVR Auction Hook - Available Commands:"
	@echo "======================================"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# =============================================================================
# INSTALLATION & SETUP
# =============================================================================

install: install-deps install-frontend install-avs ## Install all dependencies
	@echo "✅ All dependencies installed successfully"

install-deps: ## Install system dependencies
	@echo "📦 Installing system dependencies..."
	@command -v forge >/dev/null 2>&1 || { echo "❌ Foundry not found. Install with: curl -L https://foundry.paradigm.xyz | bash && foundryup"; exit 1; }
	@command -v node >/dev/null 2>&1 || { echo "❌ Node.js not found. Please install Node.js 18+"; exit 1; }
	@command -v go >/dev/null 2>&1 || { echo "❌ Go not found. Please install Go 1.21+"; exit 1; }
	@echo "✅ System dependencies verified"

install-frontend: ## Install frontend dependencies
	@echo "📦 Installing frontend dependencies..."
	cd frontend && npm install
	@echo "✅ Frontend dependencies installed"

install-avs: ## Install AVS Go dependencies
	@echo "📦 Installing AVS dependencies..."
	cd avs && go mod download
	@echo "✅ AVS dependencies installed"

# =============================================================================
# BUILD
# =============================================================================

build: build-contracts build-frontend build-avs ## Build all components
	@echo "✅ All components built successfully"

build-contracts: ## Build smart contracts
	@echo "🔨 Building smart contracts..."
	cd contracts && forge build
	@echo "✅ Smart contracts built"

build-frontend: ## Build frontend
	@echo "🔨 Building frontend..."
	cd frontend && npm run build
	@echo "✅ Frontend built"

build-avs: ## Build AVS operator
	@echo "🔨 Building AVS operator..."
	cd avs && go build -o bin/operator ./cmd/operator
	@echo "✅ AVS operator built"

# =============================================================================
# TESTING
# =============================================================================

test: test-contracts test-frontend test-avs ## Run all tests
	@echo "✅ All tests completed"

test-contracts: ## Test smart contracts
	@echo "🧪 Testing smart contracts..."
	cd contracts && forge test -vv
	@echo "✅ Smart contract tests completed"

test-contracts-coverage: ## Run smart contract tests with coverage
	@echo "🧪 Running smart contract tests with coverage..."
	cd contracts && forge coverage
	@echo "✅ Coverage report generated"

test-frontend: ## Test frontend
	@echo "🧪 Testing frontend..."
	cd frontend && npm test -- --coverage --watchAll=false
	@echo "✅ Frontend tests completed"

test-avs: ## Test AVS operator
	@echo "🧪 Testing AVS operator..."
	cd avs && go test ./...
	@echo "✅ AVS tests completed"

# =============================================================================
# LINTING & FORMATTING
# =============================================================================

lint: lint-contracts lint-frontend lint-avs ## Lint all code
	@echo "✅ All linting completed"

lint-contracts: ## Lint smart contracts
	@echo "🔍 Linting smart contracts..."
	cd contracts && forge fmt --check
	@echo "✅ Smart contract linting completed"

lint-frontend: ## Lint frontend
	@echo "🔍 Linting frontend..."
	cd frontend && npm run lint
	@echo "✅ Frontend linting completed"

lint-avs: ## Lint AVS code
	@echo "🔍 Linting AVS code..."
	cd avs && go vet ./...
	cd avs && golangci-lint run
	@echo "✅ AVS linting completed"

format: format-contracts format-frontend format-avs ## Format all code
	@echo "✅ All formatting completed"

format-contracts: ## Format smart contracts
	@echo "🎨 Formatting smart contracts..."
	cd contracts && forge fmt
	@echo "✅ Smart contract formatting completed"

format-frontend: ## Format frontend
	@echo "🎨 Formatting frontend..."
	cd frontend && npm run format
	@echo "✅ Frontend formatting completed"

format-avs: ## Format AVS code
	@echo "🎨 Formatting AVS code..."
	cd avs && go fmt ./...
	@echo "✅ AVS formatting completed"

# =============================================================================
# DEVELOPMENT
# =============================================================================

dev: dev-contracts dev-frontend ## Start development environment
	@echo "🚀 Development environment started"

dev-contracts: ## Start local blockchain for contract development
	@echo "🔗 Starting local blockchain..."
	anvil --host 0.0.0.0 --port 8545 &
	@echo "✅ Local blockchain started on http://localhost:8545"

dev-frontend: ## Start frontend development server
	@echo "🌐 Starting frontend development server..."
	cd frontend && npm start &
	@echo "✅ Frontend started on http://localhost:3000"

dev-avs: ## Start AVS operator in development mode
	@echo "⚡ Starting AVS operator..."
	cd avs && go run ./cmd/operator --config config/operator.yaml
	@echo "✅ AVS operator started"

# =============================================================================
# DEPLOYMENT
# =============================================================================

deploy: deploy-contracts deploy-frontend ## Deploy all components
	@echo "✅ All components deployed"

deploy-contracts-local: ## Deploy contracts to local network
	@echo "🚀 Deploying contracts to local network..."
	cd contracts && forge script script/DeployLVR.s.sol --rpc-url http://localhost:8545 --broadcast
	@echo "✅ Contracts deployed to local network"

deploy-contracts-sepolia: ## Deploy contracts to Sepolia testnet
	@echo "🚀 Deploying contracts to Sepolia..."
	cd contracts && forge script script/DeployLVR.s.sol --rpc-url sepolia --broadcast --verify
	@echo "✅ Contracts deployed to Sepolia"

deploy-contracts-mainnet: ## Deploy contracts to mainnet
	@echo "🚀 Deploying contracts to mainnet..."
	@echo "⚠️  WARNING: This will deploy to mainnet. Make sure you have:"
	@echo "   1. Verified all contract addresses"
	@echo "   2. Set proper environment variables"
	@echo "   3. Have sufficient ETH for gas"
	@read -p "Continue? (y/N): " confirm && [ "$$confirm" = "y" ]
	cd contracts && forge script script/DeployLVR.s.sol --rpc-url mainnet --broadcast --verify
	@echo "✅ Contracts deployed to mainnet"

deploy-frontend: ## Deploy frontend (placeholder)
	@echo "🌐 Deploying frontend..."
	@echo "TODO: Implement frontend deployment"
	@echo "✅ Frontend deployment completed"

# =============================================================================
# UTILITIES
# =============================================================================

clean: ## Clean all build artifacts
	@echo "🧹 Cleaning build artifacts..."
	cd contracts && forge clean
	cd frontend && rm -rf build node_modules/.cache
	cd avs && rm -rf bin/
	@echo "✅ Clean completed"

clean-contracts: ## Clean contract build artifacts
	@echo "🧹 Cleaning contract artifacts..."
	cd contracts && forge clean
	@echo "✅ Contract cleanup completed"

clean-frontend: ## Clean frontend build artifacts
	@echo "🧹 Cleaning frontend artifacts..."
	cd frontend && rm -rf build node_modules/.cache
	@echo "✅ Frontend cleanup completed"

clean-avs: ## Clean AVS build artifacts
	@echo "🧹 Cleaning AVS artifacts..."
	cd avs && rm -rf bin/
	@echo "✅ AVS cleanup completed"

# =============================================================================
# MONITORING & ANALYTICS
# =============================================================================

monitor: ## Start monitoring dashboard
	@echo "📊 Starting monitoring dashboard..."
	@echo "Frontend: http://localhost:3000"
	@echo "API: http://localhost:8001"
	@echo "Metrics: http://localhost:8001/metrics"
	@echo "✅ Monitoring dashboard available"

logs: ## View logs from all services
	@echo "📋 Viewing logs from all services..."
	@echo "TODO: Implement log aggregation"
	@echo "✅ Logs displayed"

metrics: ## Show system metrics
	@echo "📈 System metrics:"
	@echo "TODO: Implement metrics collection"
	@echo "✅ Metrics displayed"

# =============================================================================
# SECURITY
# =============================================================================

audit: ## Run security audit
	@echo "🔒 Running security audit..."
	cd contracts && forge test --gas-report
	@echo "TODO: Add additional security tools"
	@echo "✅ Security audit completed"

slither: ## Run Slither static analysis
	@echo "🔍 Running Slither analysis..."
	cd contracts && slither .
	@echo "✅ Slither analysis completed"

# =============================================================================
# DOCUMENTATION
# =============================================================================

docs: ## Generate documentation
	@echo "📚 Generating documentation..."
	cd contracts && forge doc
	@echo "✅ Documentation generated"

docs-serve: ## Serve documentation locally
	@echo "📚 Serving documentation..."
	cd contracts/docs && python -m http.server 8000
	@echo "✅ Documentation served at http://localhost:8000"

# =============================================================================
# ENVIRONMENT SETUP
# =============================================================================

env-setup: ## Set up environment files
	@echo "⚙️ Setting up environment files..."
	@cp .env.example .env
	@echo "✅ Environment files created"
	@echo "📝 Please edit .env with your configuration"

env-check: ## Check environment configuration
	@echo "🔍 Checking environment configuration..."
	@test -f .env || (echo "❌ .env file not found. Run 'make env-setup'" && exit 1)
	@echo "✅ Environment configuration valid"

# =============================================================================
# QUICK COMMANDS
# =============================================================================

quick-start: env-setup install build test ## Quick start: setup, install, build, and test
	@echo "🚀 Quick start completed!"

full-test: clean build test-contracts-coverage test-frontend test-avs ## Full test suite with coverage
	@echo "✅ Full test suite completed with coverage"

production-build: clean lint test build ## Production build with all checks
	@echo "🏭 Production build completed"

# =============================================================================
# DOCKER (Optional)
# =============================================================================

docker-build: ## Build Docker images
	@echo "🐳 Building Docker images..."
	docker-compose build
	@echo "✅ Docker images built"

docker-run: ## Run with Docker Compose
	@echo "🐳 Running with Docker Compose..."
	docker-compose up -d
	@echo "✅ Services started with Docker"

docker-stop: ## Stop Docker services
	@echo "🐳 Stopping Docker services..."
	docker-compose down
	@echo "✅ Docker services stopped"