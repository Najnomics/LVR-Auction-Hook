// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";

import {ChainlinkPriceOracle} from "../src/ChainlinkPriceOracle.sol";
import {IPriceOracle} from "../src/interfaces/IPriceOracle.sol";
import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title ChainlinkPriceOracleTest
 * @notice Comprehensive test suite for Chainlink Price Oracle
 */
contract ChainlinkPriceOracleTest is Test {
    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/
    
    ChainlinkPriceOracle public oracle;
    MockPriceFeed public mockPriceFeed;
    
    address public owner;
    Currency public token0;
    Currency public token1;
    Currency public token2;
    Currency public token3;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/
    
    function setUp() public {
        owner = address(this);
        
        // Create test tokens
        token0 = Currency.wrap(makeAddr("token0"));
        token1 = Currency.wrap(makeAddr("token1"));
        token2 = Currency.wrap(makeAddr("token2"));
        token3 = Currency.wrap(makeAddr("token3"));
        
        // Deploy oracle
        oracle = new ChainlinkPriceOracle(owner);
        
        // Deploy mock price feed
        mockPriceFeed = new MockPriceFeed();
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testConstructor() public {
        assertEq(oracle.owner(), owner);
    }
    
    function testConstants() public {
        assertEq(oracle.MAX_PRICE_STALENESS(), 3600);
        assertEq(oracle.MIN_VALID_PRICE(), 1);
        assertEq(oracle.MAX_VALID_PRICE(), 1e30);
    }
    
    function testAddPriceFeed() public {
        oracle.addPriceFeed(token0, token1, address(mockPriceFeed));
        
        // Verify price feed was added
        bytes32 pairKey = keccak256(abi.encodePacked(token0, token1));
        assertEq(address(oracle.priceFeeds(pairKey)), address(mockPriceFeed));
    }
    
    function testAddPriceFeedInvalidAddress() public {
        vm.expectRevert("Invalid price feed address");
        oracle.addPriceFeed(token0, token1, address(0));
    }
    
    function testAddPriceFeedOnlyOwner() public {
        vm.prank(address(0x1));
        vm.expectRevert();
        oracle.addPriceFeed(token0, token1, address(mockPriceFeed));
    }
    
    function testRemovePriceFeed() public {
        // Add price feed first
        oracle.addPriceFeed(token0, token1, address(mockPriceFeed));
        
        // Remove price feed
        oracle.removePriceFeed(token0, token1);
        
        // Verify price feed was removed
        bytes32 pairKey = keccak256(abi.encodePacked(token0, token1));
        assertEq(address(oracle.priceFeeds(pairKey)), address(0));
    }
    
    function testRemovePriceFeedOnlyOwner() public {
        vm.prank(address(0x1));
        vm.expectRevert();
        oracle.removePriceFeed(token0, token1);
    }
    
    function testGetPrice() public {
        // Set up mock price feed
        mockPriceFeed.setMockData(3245.67e8, 8, block.timestamp);
        
        // Add price feed
        oracle.addPriceFeed(token0, token1, address(mockPriceFeed));
        
        // Get price
        uint256 price = oracle.getPrice(token0, token1);
        
        // Expected: 3245.67 * 10^18 (normalized to 18 decimals)
        assertEq(price, 3245.67e18);
    }
    
    function testGetPriceNoFeedConfigured() public {
        vm.expectRevert(abi.encodeWithSignature("NoPriceFeedConfigured()"));
        oracle.getPrice(token0, token1);
    }
    
    function testGetPriceInvalidData() public {
        // Set up mock with invalid data (negative price)
        mockPriceFeed.setMockData(-100, 8, block.timestamp);
        oracle.addPriceFeed(token0, token1, address(mockPriceFeed));
        
        vm.expectRevert(abi.encodeWithSignature("InvalidPriceData()"));
        oracle.getPrice(token0, token1);
    }
    
    function testGetPriceStaleData() public {
        // Set up mock with stale data (older than 1 hour)
        mockPriceFeed.setMockData(3245.67e8, 8, block.timestamp - 3700);
        oracle.addPriceFeed(token0, token1, address(mockPriceFeed));
        
        vm.expectRevert(abi.encodeWithSignature("StalePriceData()"));
        oracle.getPrice(token0, token1);
    }
    
    function testGetPriceAtTime() public {
        // Set up mock price feed
        mockPriceFeed.setMockData(3245.67e8, 8, block.timestamp);
        oracle.addPriceFeed(token0, token1, address(mockPriceFeed));
        
        // Get price at time (should return current price for this mock)
        uint256 price = oracle.getPriceAtTime(token0, token1, block.timestamp - 1000);
        
        assertEq(price, 3245.67e18);
    }
    
    function testIsPriceStale() public {
        // Test with no feed
        assertTrue(oracle.isPriceStale(token0, token1));
        
        // Add fresh feed
        mockPriceFeed.setMockData(3245.67e8, 8, block.timestamp);
        oracle.addPriceFeed(token0, token1, address(mockPriceFeed));
        
        assertFalse(oracle.isPriceStale(token0, token1));
        
        // Make feed stale
        mockPriceFeed.setMockData(3245.67e8, 8, block.timestamp - 3700);
        assertTrue(oracle.isPriceStale(token0, token1));
    }
    
    function testGetLastUpdateTime() public {
        uint256 updateTime = block.timestamp - 100;
        
        mockPriceFeed.setMockData(3245.67e8, 8, updateTime);
        oracle.addPriceFeed(token0, token1, address(mockPriceFeed));
        
        uint256 lastUpdate = oracle.getLastUpdateTime(token0, token1);
        assertEq(lastUpdate, updateTime);
    }
    
    function testGetLastUpdateTimeNoFeed() public {
        uint256 lastUpdate = oracle.getLastUpdateTime(token0, token1);
        assertEq(lastUpdate, 0);
    }
    
    function testPriceNormalization() public {
        // Test different decimal places
        oracle.addPriceFeed(token0, token1, address(mockPriceFeed));
        
        // Test 8 decimals (BTC/USD style)
        mockPriceFeed.setMockData(43250e8, 8, block.timestamp);
        uint256 price8Dec = oracle.getPrice(token0, token1);
        assertEq(price8Dec, 43250e18);
        
        // Test 6 decimals (some stablecoins)
        mockPriceFeed.setMockData(1e6, 6, block.timestamp);
        uint256 price6Dec = oracle.getPrice(token0, token1);
        assertEq(price6Dec, 1e18);
        
        // Test 18 decimals (ETH style)
        mockPriceFeed.setMockData(3245e18, 18, block.timestamp);
        uint256 price18Dec = oracle.getPrice(token0, token1);
        assertEq(price18Dec, 3245e18);
    }
    
    function testPriceBoundsValidation() public {
        oracle.addPriceFeed(token0, token1, address(mockPriceFeed));
        
        // Test minimum valid price
        mockPriceFeed.setMockData(1, 18, block.timestamp);
        uint256 minPrice = oracle.getPrice(token0, token1);
        assertEq(minPrice, 1);
        
        // Test maximum valid price
        mockPriceFeed.setMockData(1e30, 18, block.timestamp);
        uint256 maxPrice = oracle.getPrice(token0, token1);
        assertEq(maxPrice, 1e30);
        
        // Test price below minimum
        mockPriceFeed.setMockData(0, 18, block.timestamp);
        vm.expectRevert(abi.encodeWithSignature("InvalidPriceData()"));
        oracle.getPrice(token0, token1);
        
        // Test price above maximum
        mockPriceFeed.setMockData(1e31, 18, block.timestamp);
        vm.expectRevert(abi.encodeWithSignature("InvalidPriceData()"));
        oracle.getPrice(token0, token1);
    }
    
    function testTokenPairOrdering() public {
        // Add price feed with token0 < token1
        oracle.addPriceFeed(token0, token1, address(mockPriceFeed));
        
        // Should work with reversed order too
        mockPriceFeed.setMockData(3245.67e8, 8, block.timestamp);
        
        uint256 price1 = oracle.getPrice(token0, token1);
        uint256 price2 = oracle.getPrice(token1, token0);
        
        assertEq(price1, price2);
    }
    
    function testMultiplePriceFeeds() public {
        MockPriceFeed feed1 = new MockPriceFeed();
        MockPriceFeed feed2 = new MockPriceFeed();
        
        // Add multiple price feeds
        oracle.addPriceFeed(token0, token1, address(feed1));
        oracle.addPriceFeed(token0, token2, address(feed2));
        
        // Set different prices
        feed1.setMockData(3245.67e8, 8, block.timestamp);
        feed2.setMockData(125.43e8, 8, block.timestamp);
        
        // Test both feeds
        uint256 price1 = oracle.getPrice(token0, token1);
        uint256 price2 = oracle.getPrice(token0, token2);
        
        assertEq(price1, 3245.67e18);
        assertEq(price2, 125.43e18);
    }

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/
    
    function testEvents() public {
        // Test PriceFeedAdded event
        vm.expectEmit(true, true, true, true);
        emit PriceFeedAdded(token0, token1, address(mockPriceFeed));
        oracle.addPriceFeed(token0, token1, address(mockPriceFeed));
        
        // Test PriceFeedRemoved event
        vm.expectEmit(true, true, true, true);
        emit PriceFeedRemoved(token0, token1);
        oracle.removePriceFeed(token0, token1);
    }
    
    event PriceFeedAdded(Currency token0, Currency token1, address priceFeed);
    event PriceFeedRemoved(Currency token0, Currency token1);
}

/*//////////////////////////////////////////////////////////////
                            MOCK CONTRACTS
//////////////////////////////////////////////////////////////*/

contract MockPriceFeed is AggregatorV3Interface {
    int256 private mockAnswer;
    uint8 private mockDecimals;
    uint256 private mockUpdatedAt;
    
    function setMockData(int256 _answer, uint8 _decimals, uint256 _updatedAt) external {
        mockAnswer = _answer;
        mockDecimals = _decimals;
        mockUpdatedAt = _updatedAt;
    }
    
    function latestRoundData() external view override returns (
        uint80,
        int256 answer,
        uint256,
        uint256 updatedAt,
        uint80
    ) {
        return (0, mockAnswer, 0, mockUpdatedAt, 0);
    }
    
    function decimals() external view override returns (uint8) {
        return mockDecimals;
    }
    
    // Other required functions (not used in tests)
    function description() external pure override returns (string memory) {
        return "Mock Price Feed";
    }
    
    function version() external pure override returns (uint256) {
        return 1;
    }
    
    function getRoundData(uint80) external pure override returns (
        uint80,
        int256,
        uint256,
        uint256,
        uint80
    ) {
        revert("Not implemented");
    }
}
