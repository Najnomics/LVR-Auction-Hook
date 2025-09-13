// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {LVRAuctionHook} from "../src/LVRAuctionHook.sol";
import {AuctionLib} from "../src/libraries/AuctionLib.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {IAVSDirectory} from "../src/interfaces/IAVSDirectory.sol";
import {IPriceOracle} from "../src/interfaces/IPriceOracle.sol";
import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {PoolId} from "@uniswap/v4-core/types/PoolId.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "@uniswap/v4-core/types/BeforeSwapDelta.sol";

/**
 * @title Test version of LVRAuctionHook that skips address validation
 * @notice This allows deployment to any address for testing purposes
 */
contract TestLVRAuctionHook is LVRAuctionHook {
    // Test variables to mock pool price
    mapping(bytes32 => uint256) public mockPoolPrices;
    
    // Allow receiving ETH for testing MEV distribution
    receive() external payable override {}
    
    constructor(
        IPoolManager _poolManager,
        IAVSDirectory _avsDirectory,
        IPriceOracle _priceOracle,
        address _feeRecipient,
        uint256 _lvrThreshold
    ) LVRAuctionHook(
        _poolManager,
        _avsDirectory,
        _priceOracle,
        _feeRecipient,
        _lvrThreshold
    ) {}
    
    /// @dev Override to skip hook address validation during testing
    function validateHookAddress(BaseHook) internal pure override {
        // Skip validation for testing
    }
    
    /// @dev Set mock pool price for testing
    function setMockPoolPrice(PoolKey calldata key, uint256 price) external {
        bytes32 poolKey = keccak256(abi.encode(key.currency0, key.currency1, key.fee));
        mockPoolPrices[poolKey] = price;
    }
    
    /// @dev Test function to create auction manually
    function testCreateAuction(
        PoolId poolId,
        bytes32 auctionId,
        uint256 startTime,
        uint256 duration,
        bool isActive,
        bool isComplete
    ) external {
        auctions[auctionId] = AuctionLib.Auction({
            poolId: poolId,
            startTime: startTime,
            duration: duration,
            isActive: isActive,
            isComplete: isComplete,
            winner: address(0),
            winningBid: 0,
            totalBids: 0
        });
    }
    
    /// @dev Test function to set active auction
    function testSetActiveAuction(PoolId poolId, bytes32 auctionId) external {
        activeAuctions[poolId] = auctionId;
    }
    
    /// @dev Test function to set LP liquidity
    function testSetLpLiquidity(PoolId poolId, address lp, uint256 amount) external {
        lpLiquidity[poolId][lp] = amount;
    }
    
    /// @dev Test function to set total liquidity
    function testSetTotalLiquidity(PoolId poolId, uint256 amount) external {
        totalLiquidity[poolId] = amount;
    }
    
    /// @dev Test function to set pool rewards
    function testSetPoolRewards(PoolId poolId, uint256 amount) external {
        poolRewards[poolId] = amount;
    }
    
    /// @dev Test function to submit auction result (bypasses timing checks)
    function testSubmitAuctionResult(
        bytes32 auctionId,
        address winner,
        uint256 winningBid
    ) external {
        AuctionLib.Auction storage auction = auctions[auctionId];
        require(auction.isActive, "EigenLVR: auction not active");
        
        auction.isActive = false;
        auction.isComplete = true;
        auction.winner = winner;
        auction.winningBid = winningBid;
    }
    
    /// @dev Test function to submit auction result with timing check
    function testSubmitAuctionResultWithTimingCheck(
        bytes32 auctionId,
        address winner,
        uint256 winningBid
    ) external {
        AuctionLib.Auction storage auction = auctions[auctionId];
        require(auction.isActive, "EigenLVR: auction not active");
        require(auction.isAuctionEnded(), "EigenLVR: auction not ended");
        
        auction.isActive = false;
        auction.isComplete = true;
        auction.winner = winner;
        auction.winningBid = winningBid;
    }
    
    /// @dev Test function to claim rewards
    function testClaimRewards(PoolId poolId) external {
        require(lpLiquidity[poolId][msg.sender] > 0, "EigenLVR: no liquidity provided");
        
        uint256 totalRewards = poolRewards[poolId];
        uint256 totalLp = totalLiquidity[poolId];
        uint256 userLiquidity = lpLiquidity[poolId][msg.sender];
        
        uint256 userRewards = (totalRewards * userLiquidity) / totalLp;
        
        if (userRewards > 0) {
            poolRewards[poolId] -= userRewards;
            payable(msg.sender).transfer(userRewards);
        }
    }
    
    /// @dev Test function to call beforeSwap
    function testBeforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4, BeforeSwapDelta, uint24) {
        return _beforeSwap(sender, key, params, hookData);
    }
    
    /// @dev Test function to call afterSwap
    function testAfterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external returns (bytes4, int128) {
        return _afterSwap(sender, key, params, delta, hookData);
    }
    
    /// @dev Test function to call beforeAddLiquidity
    function testBeforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {
        return _beforeAddLiquidity(sender, key, params, hookData);
    }
    
    /// @dev Test function to call beforeRemoveLiquidity
    function testBeforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {
        return _beforeRemoveLiquidity(sender, key, params, hookData);
    }
    
    /// @dev Override _getPoolPrice to use mock prices
    function _getPoolPrice(PoolKey calldata key) internal view override returns (uint256) {
        bytes32 poolKey = keccak256(abi.encode(key.currency0, key.currency1, key.fee));
        uint256 mockPrice = mockPoolPrices[poolKey];
        
        if (mockPrice > 0) {
            return mockPrice;
        }
        
        // Fallback to parent implementation
        return super._getPoolPrice(key);
    }
}
