// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "@uniswap/v4-core/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {IAVSDirectory} from "../../src/interfaces/IAVSDirectory.sol";
import {IPriceOracle} from "../../src/interfaces/IPriceOracle.sol";

contract SimplePoolManager {
    function getSlot0(PoolId) external pure returns (uint160, int24, uint24, uint256) {
        return (79228162514264337593543950336, 0, 0, 0);
    }
}

contract MockAVSDirectory is IAVSDirectory {
    mapping(address => mapping(address => bool)) public operatorRegistrations;
    mapping(address => mapping(address => uint256)) public operatorStakes;
    
    function registerOperatorToAVS(
        address operator,
        bytes calldata
    ) external override {
        operatorRegistrations[msg.sender][operator] = true;
    }
    
    function deregisterOperatorFromAVS(address operator) external override {
        operatorRegistrations[msg.sender][operator] = false;
    }
    
    function isOperatorRegistered(address avs, address operator) external view override returns (bool) {
        return operatorRegistrations[avs][operator];
    }
    
    function getOperatorStake(address avs, address operator) external view override returns (uint256) {
        return operatorStakes[avs][operator];
    }
    
    // For single-parameter version used in our code
    function isOperatorRegistered(address operator) external pure returns (bool) {
        return true;
    }
    
    function setOperatorStake(address avs, address operator, uint256 stake) external {
        operatorStakes[avs][operator] = stake;
    }
}

contract MockPriceOracle is IPriceOracle {
    mapping(Currency => mapping(Currency => uint256)) public prices;
    mapping(Currency => mapping(Currency => uint256)) public updateTimes;
    
    function setPrice(Currency token0, Currency token1, uint256 price) external {
        prices[token0][token1] = price;
        updateTimes[token0][token1] = block.timestamp;
    }
    
    // Compatibility method for legacy test calls
    function setPrice(uint256 priceA, uint256 priceB) external {
        Currency token0 = Currency.wrap(address(0x100));
        Currency token1 = Currency.wrap(address(0x200));
        prices[token0][token1] = priceA;
        prices[token1][token0] = priceB;
        updateTimes[token0][token1] = block.timestamp;
        updateTimes[token1][token0] = block.timestamp;
    }
    
    function getPrice(Currency token0, Currency token1) external view override returns (uint256) {
        uint256 price = prices[token0][token1];
        return price > 0 ? price : 1e18;
    }
    
    function getPriceAtTime(
        Currency token0,
        Currency token1,
        uint256 timestamp
    ) external view override returns (uint256 price) {
        if (timestamp <= updateTimes[token0][token1]) {
            return prices[token0][token1];
        }
        return 0;
    }
    
    function isPriceStale(Currency token0, Currency token1) external view override returns (bool isStale) {
        return block.timestamp - updateTimes[token0][token1] > 3600; // 1 hour staleness
    }
    
    function getLastUpdateTime(Currency token0, Currency token1) external view override returns (uint256 timestamp) {
        return updateTimes[token0][token1];
    }
}