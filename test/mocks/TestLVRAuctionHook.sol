// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {LVRAuctionHook} from "../../src/hooks/LVRAuctionHook.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {IAVSDirectory} from "../../src/interfaces/IAVSDirectory.sol";
import {IPriceOracle} from "../../src/interfaces/IPriceOracle.sol";
import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {PoolId} from "@uniswap/v4-core/types/PoolId.sol";
import {BeforeSwapDelta} from "@uniswap/v4-core/types/BeforeSwapDelta.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/types/PoolOperation.sol";

/**
 * @title TestLVRAuctionHook
 * @notice Test version of LVRAuctionHook that bypasses address validation
 */
contract TestLVRAuctionHook is LVRAuctionHook {
    constructor(
        IPoolManager _poolManager,
        IAVSDirectory _avsDirectory,
        IPriceOracle _priceOracle,
        address _feeRecipient,
        uint256 _lvrThreshold
    ) LVRAuctionHook(_poolManager, _avsDirectory, _priceOracle, _feeRecipient, _lvrThreshold) {}

    /// @dev Override to disable hook address validation for testing
    function validateHookAddress(BaseHook _this) internal pure override {
        // Skip validation in tests
    }

    /// @dev Public wrapper for testing internal price inversion logic
    function shouldInvertPrice(Currency token0, Currency token1) external pure returns (bool) {
        return _shouldInvertPrice(token0, token1);
    }

    /// @dev Mock pool price for testing
    uint256 public mockPoolPrice = 1e18;
    
    /// @dev Set mock pool price for testing
    function setMockPoolPrice(uint256 _price) external {
        mockPoolPrice = _price;
    }
    
    /// @dev Set pool rewards for testing
    function setPoolRewards(PoolId poolId, uint256 rewards) external {
        poolRewards[poolId] = rewards;
    }
    
    /// @dev Override to use mock pool price for testing
    function _getPoolPrice(PoolKey calldata /* key */) internal view override returns (uint256) {
        return mockPoolPrice;
    }

    /// @dev Public wrapper for testing beforeSwap functionality
    function testBeforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4, BeforeSwapDelta, uint24) {
        return _beforeSwap(sender, key, params, hookData);
    }

    /// @dev Public wrapper for testing afterSwap functionality  
    function testAfterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external returns (bytes4, int128) {
        return _afterSwap(sender, key, params, delta, hookData);
    }

    /// @dev Public wrapper for testing beforeAddLiquidity functionality
    function testBeforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {
        return _beforeAddLiquidity(sender, key, params, hookData);
    }

    /// @dev Public wrapper for testing beforeRemoveLiquidity functionality
    function testBeforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {
        return _beforeRemoveLiquidity(sender, key, params, hookData);
    }
}