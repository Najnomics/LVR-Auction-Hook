// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "@uniswap/v4-core/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";

contract MockPoolManager {
    function getSlot0(PoolId) external pure returns (uint160, int24, uint24, uint256) {
        return (79228162514264337593543950336, 0, 0, 0);
    }
}

contract MockAVSDirectory {
    function isOperatorRegistered(address) external pure returns (bool) {
        return true;
    }
}

contract MockPriceOracle {
    mapping(Currency => mapping(Currency => uint256)) public prices;
    
    constructor() {
        // Set default prices
    }
    
    function setPrice(Currency token0, Currency token1, uint256 price) external {
        prices[token0][token1] = price;
    }
    
    function getPrice(Currency token0, Currency token1) external view returns (uint256) {
        uint256 price = prices[token0][token1];
        return price > 0 ? price : 1e18; // Default to 1:1 if not set
    }
}