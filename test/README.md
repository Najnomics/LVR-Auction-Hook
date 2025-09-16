# Test Structure

This directory contains comprehensive tests for the LVR Auction Hook project, organized by test type and functionality.

## Directory Structure

### 📁 `unit/` - Unit Tests
Tests individual components in isolation with mocked dependencies.

- **`AuctionLib.t.sol`** - Tests for auction library functions and data structures
- **`AuctionLibEnhanced.t.sol`** - Enhanced auction library tests with edge cases
- **`ChainlinkPriceOracle.t.sol`** - Tests for Chainlink price oracle integration
- **`HookMiner.t.sol`** - Tests for Uniswap V4 hook address mining utility

### 📁 `integration/` - Integration Tests
Tests component interactions and end-to-end workflows.

- **`LVRAuctionHook.t.sol`** - Core hook integration tests
- **`LVRAuctionHookAdmin.t.sol`** - Administrative function tests
- **`LVRAuctionHookAuction.t.sol`** - Auction mechanism integration tests
- **`LVRAuctionServiceManager.t.sol`** - AVS service manager integration tests

### 📁 `coverage/` - Coverage Tests
Ensures comprehensive test coverage of all contract functions.

- **`LVRAuctionHook100Coverage.t.sol`** - 100% coverage tests for main hook
- **`LVRAuctionHookComplete100.t.sol`** - Complete coverage with edge cases
- **`LVRAuctionHookFullCoverage.t.sol`** - Full coverage including all branches
- **`UnitTestsForCoverage.t.sol`** - Additional unit tests for coverage

### 📁 `fuzz/` - Fuzz Tests
Property-based testing with random inputs to find edge cases.

- **`AuctionFuzz.t.sol`** - Fuzz testing for auction logic
- **`PriceOracleFuzz.t.sol`** - Fuzz testing for price calculations

### 📁 `invariants/` - Invariant Tests
Tests that system invariants are maintained across all operations.

- **`LVRAuctionInvariants.t.sol`** - Invariant tests for LVR auction system

### 📁 `utils/` - Utility Tests
Tests for utility functions and helper contracts.

- **`HookMinerComprehensive.t.sol`** - Comprehensive HookMiner tests

### 📁 `mocks/` - Mock Contracts
Mock contracts and test helpers.

- **`TestLVRAuctionHook.sol`** - Test hook contract for integration testing

## Running Tests

### Run All Tests
```bash
forge test
```

### Run by Category
```bash
# Unit tests only
forge test --match-path "test/unit/*"

# Integration tests only
forge test --match-path "test/integration/*"

# Coverage tests only
forge test --match-path "test/coverage/*"

# Fuzz tests only
forge test --match-path "test/fuzz/*"

# Invariant tests only
forge test --match-path "test/invariants/*"
```

### Run Specific Test Files
```bash
# Run specific test file
forge test --match-path "test/unit/AuctionLib.t.sol"

# Run with verbosity
forge test --match-path "test/integration/LVRAuctionHook.t.sol" -vvv
```

### Coverage Analysis
```bash
# Generate coverage report
forge coverage

# Coverage with specific tests
forge coverage --match-path "test/coverage/*"
```

## Test Categories

### 🔧 Unit Tests
- **Purpose**: Test individual functions and components in isolation
- **Scope**: Single contract/library functions
- **Dependencies**: Mocked external contracts
- **Execution**: Fast, deterministic

### 🔗 Integration Tests
- **Purpose**: Test interactions between multiple components
- **Scope**: Cross-contract functionality
- **Dependencies**: Real contract interactions
- **Execution**: Moderate speed, more complex setup

### 📊 Coverage Tests
- **Purpose**: Ensure all code paths are tested
- **Scope**: Complete contract functionality
- **Dependencies**: Comprehensive test scenarios
- **Execution**: Thorough but slower

### 🎲 Fuzz Tests
- **Purpose**: Find edge cases with random inputs
- **Scope**: Property-based testing
- **Dependencies**: Random input generation
- **Execution**: Can be slow, finds unexpected bugs

### ⚖️ Invariant Tests
- **Purpose**: Ensure system properties are maintained
- **Scope**: System-wide invariants
- **Dependencies**: State exploration
- **Execution**: Can be very slow, finds logical errors

## Best Practices

1. **Unit tests** should be fast and isolated
2. **Integration tests** should test real interactions
3. **Coverage tests** should aim for 100% coverage
4. **Fuzz tests** should test properties, not specific inputs
5. **Invariant tests** should test system-wide properties

## Test Naming Convention

- Unit tests: `test_[FunctionName]_[Scenario]()`
- Integration tests: `test_[Component]_[Interaction]()`
- Coverage tests: `test_Coverage_[FunctionName]()`
- Fuzz tests: `testFuzz_[Property]_[Parameters]()`
- Invariant tests: `invariant_[Property]()`

## Continuous Integration

All test categories should pass in CI:

- Unit tests: Required for all PRs
- Integration tests: Required for all PRs
- Coverage tests: Must maintain >95% coverage
- Fuzz tests: Run nightly or on major changes
- Invariant tests: Run on major releases
