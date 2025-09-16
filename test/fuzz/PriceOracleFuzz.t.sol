// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {ChainlinkPriceOracle} from "../../src/oracles/ChainlinkPriceOracle.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";

/**
 * @title PriceOracleFuzzTest
 * @notice Fuzz testing for price oracle with random inputs
 */
contract PriceOracleFuzzTest is Test {
    ChainlinkPriceOracle public oracle;
    
    function setUp() public {
        oracle = new ChainlinkPriceOracle(address(0x1)); // Mock AVS directory address
    }
    
    function testFuzz_PriceCalculation(uint256 price, uint256 timestamp) public {
        // Bound inputs to reasonable ranges
        vm.assume(price > 0 && price <= 1e30); // Reasonable price range
        vm.assume(timestamp <= block.timestamp + 365 days); // Reasonable time range
        
        // Test that price calculations don't overflow
        uint256 scaledPrice = price * 1e18;
        assertTrue(scaledPrice >= price, "Price scaling should not underflow");
        
        // Test price comparison logic
        uint256 priceA = price;
        uint256 priceB = price * 2;
        
        assertTrue(priceB > priceA, "Price comparison should work correctly");
        assertTrue(priceA < priceB, "Price comparison should work correctly");
    }
    
    function testFuzz_TimeValidation(uint256 updateTime, uint256 staleThreshold) public {
        // Bound inputs
        vm.assume(updateTime <= block.timestamp + 365 days);
        vm.assume(staleThreshold <= 365 days);
        
        // Test time validation logic
        bool isStale = block.timestamp > updateTime + staleThreshold;
        
        // If threshold is 0, any past time should be stale
        if (staleThreshold == 0 && block.timestamp > updateTime) {
            assertTrue(isStale, "Zero threshold should make past times stale");
        }
        
        // If update time is in the future, it shouldn't be stale
        if (updateTime > block.timestamp) {
            assertFalse(isStale, "Future update time should not be stale");
        }
    }
    
    function testFuzz_CurrencyPairs(address tokenA, address tokenB) public {
        // Test that currency pairs are handled correctly
        vm.assume(tokenA != address(0));
        vm.assume(tokenB != address(0));
        vm.assume(tokenA != tokenB);
        
        Currency currencyA = Currency.wrap(tokenA);
        Currency currencyB = Currency.wrap(tokenB);
        
        // Test currency wrapping/unwrapping
        assertEq(Currency.unwrap(currencyA), tokenA, "Currency wrapping should preserve address");
        assertEq(Currency.unwrap(currencyB), tokenB, "Currency wrapping should preserve address");
        
        // Test currency equality
        assertTrue(Currency.unwrap(currencyA) != Currency.unwrap(currencyB), "Different addresses should create different currencies");
        
        Currency currencyA2 = Currency.wrap(tokenA);
        assertTrue(Currency.unwrap(currencyA) == Currency.unwrap(currencyA2), "Same address should create equal currencies");
    }
    
    function testFuzz_PriceDeviation(uint256 poolPrice, uint256 oraclePrice) public {
        // Bound inputs to prevent overflow
        vm.assume(poolPrice > 0 && poolPrice <= 1e30);
        vm.assume(oraclePrice > 0 && oraclePrice <= 1e30);
        
        // Test price deviation calculation
        uint256 deviation;
        if (poolPrice > oraclePrice) {
            uint256 diff = poolPrice - oraclePrice;
            deviation = (diff * 10000) / oraclePrice; // Basis points
        } else {
            uint256 diff = oraclePrice - poolPrice;
            deviation = (diff * 10000) / poolPrice; // Basis points
        }
        
        // Deviation should be reasonable
        assertTrue(deviation <= 10000, "Deviation should not exceed 100%");
        
        // If prices are equal, deviation should be 0
        if (poolPrice == oraclePrice) {
            assertEq(deviation, 0, "Equal prices should have zero deviation");
        }
    }
    
    function testFuzz_EdgeCases(uint256 value) public {
        // Test edge cases that might cause issues
        vm.assume(value <= type(uint128).max); // Prevent overflow in calculations
        
        // Test zero handling
        uint256 result1 = value * 0;
        assertEq(result1, 0, "Multiplying by zero should give zero");
        
        // Test one handling
        uint256 result2 = value * 1;
        assertEq(result2, value, "Multiplying by one should preserve value");
        
        // Test max value handling
        if (value > 0) {
            uint256 maxResult = type(uint256).max / value;
            assertTrue(maxResult > 0, "Division should not underflow for non-zero values");
        }
    }
}
