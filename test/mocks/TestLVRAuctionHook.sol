// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {LVRAuctionHook} from "../../src/hooks/LVRAuctionHook.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {IAVSDirectory} from "../../src/interfaces/IAVSDirectory.sol";
import {IPriceOracle} from "../../src/interfaces/IPriceOracle.sol";
import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";

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
}