// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {TestLVRAuctionHook} from "./TestLVRAuctionHook.sol";
import {AuctionLib} from "../src/libraries/AuctionLib.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {IPriceOracle} from "../src/interfaces/IPriceOracle.sol";

import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";
import {SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";

// Mock contracts for testing
contract MockPoolManager {
    function unlock(bytes calldata) external pure returns (bytes memory) {
        return "";
    }
    function initialize(PoolKey memory, uint160) external pure returns (int24) {
        return 0;
    }
    function modifyLiquidity(PoolKey memory, ModifyLiquidityParams memory, bytes calldata) 
        external pure returns (BalanceDelta, BalanceDelta) {
        return (BalanceDelta.wrap(0), BalanceDelta.wrap(0));
    }
    function swap(PoolKey memory, SwapParams memory, bytes calldata) 
        external pure returns (BalanceDelta) {
        return BalanceDelta.wrap(0);
    }
    function donate(PoolKey memory, uint256, uint256, bytes calldata) 
        external pure returns (BalanceDelta) {
        return BalanceDelta.wrap(0);
    }
    function sync(Currency) external pure {}
    function take(Currency, address, uint256) external pure {}
    function settle(Currency) external payable returns (uint256) {
        return 0;
    }
    function settleFor(Currency, address) external payable returns (uint256) {
        return 0;
    }
    function clear(Currency, uint256) external pure {}
    function mint(address, uint256, uint256) external pure {}
    function burn(address, uint256, uint256) external pure {}
}

contract MockAVSDirectory {
    mapping(address => mapping(address => bool)) public operatorRegistered;
    mapping(address => mapping(address => uint256)) public operatorStake;
    
    function registerOperatorToAVS(address operator, bytes calldata) external {
        operatorRegistered[msg.sender][operator] = true;
        operatorStake[msg.sender][operator] = 1000 ether;
    }
    
    function deregisterOperatorFromAVS(address operator) external {
        operatorRegistered[msg.sender][operator] = false;
        operatorStake[msg.sender][operator] = 0;
    }
    
    function isOperatorRegistered(address avs, address operator) external view returns (bool) {
        return operatorRegistered[avs][operator];
    }
    
    function getOperatorStake(address avs, address operator) external view returns (uint256) {
        return operatorStake[avs][operator];
    }
    
    function setOperatorStake(address avs, address operator, uint256 stake) external {
        operatorStake[avs][operator] = stake;
    }
}

contract MockPriceOracle {
    mapping(Currency => mapping(Currency => uint256)) public prices;
    
    function getPrice(Currency token0, Currency token1) external view returns (uint256) {
        return prices[token0][token1];
    }
    
    function setPrice(Currency token0, Currency token1, uint256 price) external {
        prices[token0][token1] = price;
    }
    
    function getPriceAtTime(Currency, Currency, uint256) external pure returns (uint256) {
        return 2000e18;
    }
    
    function isPriceStale(Currency, Currency) external pure returns (bool) {
        return false;
    }
    
    function getLastUpdateTime(Currency, Currency) external pure returns (uint256) {
        return block.timestamp;
    }
}

/**
 * @title LVRAuctionHook Auction and Internal Functions Tests
 * @notice Tests auction logic and internal functions for complete coverage
 */
contract LVRAuctionHookAuctionTest is Test {
    using PoolIdLibrary for PoolKey;

    // Allow receiving ETH for testing
    receive() external payable {}

    TestLVRAuctionHook public hook;
    MockPoolManager public poolManager;
    MockAVSDirectory public avsDirectory;
    MockPriceOracle public priceOracle;
    
    address public owner = address(0x1);
    address public operator = address(0x2);
    address public lp = address(0x3);
    address public feeRecipient = address(0x4);
    address public user = address(0x5);
    address public winner = address(0x7);
    
    Currency public token0 = Currency.wrap(address(0x100));
    Currency public token1 = Currency.wrap(address(0x200));
    
    // Test with USD stablecoins
    Currency public USDC = Currency.wrap(0xA0b86a33e6441C4c27D3F50c9d6D14bDf12F4e6e);
    Currency public USDT = Currency.wrap(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    Currency public DAI = Currency.wrap(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    Currency public WETH = Currency.wrap(address(0x300));
    
    PoolKey public poolKey;
    PoolKey public usdcPoolKey;
    PoolKey public usdtPoolKey;
    PoolKey public daiPoolKey;
    PoolId public poolId;
    
    uint256 public constant LVR_THRESHOLD = 50;

    event AuctionStarted(bytes32 indexed auctionId, PoolId indexed poolId, uint256 startTime, uint256 duration);
    event AuctionEnded(bytes32 indexed auctionId, PoolId indexed poolId, address indexed winner, uint256 winningBid);
    event MEVDistributed(PoolId indexed poolId, uint256 totalAmount, uint256 lpAmount, uint256 avsAmount, uint256 protocolAmount);

    function setUp() public {
        poolManager = new MockPoolManager();
        avsDirectory = new MockAVSDirectory();
        priceOracle = new MockPriceOracle();
        
        vm.prank(owner);
        hook = new TestLVRAuctionHook(
            IPoolManager(address(poolManager)),
            avsDirectory,
            IPriceOracle(address(priceOracle)),
            feeRecipient,
            LVR_THRESHOLD
        );
        
        // Regular pool
        poolKey = PoolKey({
            currency0: token0,
            currency1: token1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        poolId = poolKey.toId();
        
        // USD stablecoin pools for price inversion testing
        usdcPoolKey = PoolKey({
            currency0: WETH,
            currency1: USDC,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        
        usdtPoolKey = PoolKey({
            currency0: USDT,
            currency1: WETH,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        
        daiPoolKey = PoolKey({
            currency0: DAI,
            currency1: WETH,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        
        vm.deal(address(hook), 100 ether);
        vm.deal(lp, 10 ether);
        vm.deal(operator, 5 ether);
        vm.deal(feeRecipient, 1 ether);
        vm.deal(winner, 2 ether);
        
        // Set default prices
        priceOracle.setPrice(token0, token1, 2000e18);
        priceOracle.setPrice(WETH, USDC, 2000e6); // 1 ETH = 2000 USDC
        priceOracle.setPrice(USDT, WETH, 5e5); // 1 USDT = 0.0005 ETH
        priceOracle.setPrice(DAI, WETH, 5e5); // 1 DAI = 0.0005 ETH
    }
    
    /*//////////////////////////////////////////////////////////////
                            AUCTION LIFECYCLE TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_AuctionCreation() public {
        // Set up price deviation to trigger auction
        hook.setMockPoolPrice(poolKey, 2000e18);
        priceOracle.setPrice(token0, token1, 2100e18); // 5% deviation
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 2e18,
            sqrtPriceLimitX96: 0
        });
        
        vm.expectEmit(true, true, false, true);
        emit AuctionStarted(bytes32(0), poolId, block.timestamp, hook.MAX_AUCTION_DURATION());
        
        hook.testBeforeSwap(user, poolKey, params, "");
        
        bytes32 auctionId = hook.activeAuctions(poolId);
        assertTrue(auctionId != bytes32(0));
        
        // Verify auction data
        (
            PoolId auctionPoolId,
            uint256 startTime,
            uint256 duration,
            bool isActive,
            bool isComplete,
            address auctionWinner,
            uint256 auctionWinningBid,
            uint256 totalBids
        ) = hook.auctions(auctionId);
        
        assertEq(PoolId.unwrap(auctionPoolId), PoolId.unwrap(poolId));
        assertEq(startTime, block.timestamp);
        assertEq(duration, hook.MAX_AUCTION_DURATION());
        assertTrue(isActive);
        assertFalse(isComplete);
        assertEq(auctionWinner, address(0));
        assertEq(auctionWinningBid, 0);
        assertEq(totalBids, 0);
    }
    
    function test_AuctionCreation_NoDeviation() public {
        // Set same prices - no deviation
        hook.setMockPoolPrice(poolKey, 2000e18);
        priceOracle.setPrice(token0, token1, 2000e18);
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 2e18,
            sqrtPriceLimitX96: 0
        });
        
        hook.testBeforeSwap(user, poolKey, params, "");
        
        bytes32 auctionId = hook.activeAuctions(poolId);
        assertEq(auctionId, bytes32(0)); // No auction created
    }
    
    function test_AuctionCreation_BelowThreshold() public {
        // Set small deviation - below threshold
        hook.setMockPoolPrice(poolKey, 2000e18);
        priceOracle.setPrice(token0, token1, 2005e18); // 0.25% deviation < 0.5%
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 2e18,
            sqrtPriceLimitX96: 0
        });
        
        hook.testBeforeSwap(user, poolKey, params, "");
        
        bytes32 auctionId = hook.activeAuctions(poolId);
        assertEq(auctionId, bytes32(0)); // No auction created
    }
    
    function test_AuctionCreation_InsignificantSwap() public {
        // Set price deviation but small swap
        hook.setMockPoolPrice(poolKey, 2000e18);
        priceOracle.setPrice(token0, token1, 2100e18); // 5% deviation
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 5e17, // 0.5 ETH - below significance threshold
            sqrtPriceLimitX96: 0
        });
        
        hook.testBeforeSwap(user, poolKey, params, "");
        
        bytes32 auctionId = hook.activeAuctions(poolId);
        assertEq(auctionId, bytes32(0)); // No auction created
    }
    
    function test_AuctionCreation_AlreadyActive() public {
        // Create first auction
        _createActiveAuction();
        bytes32 firstAuctionId = hook.activeAuctions(poolId);
        
        // Try to create another auction for same pool
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 2e18,
            sqrtPriceLimitX96: 0
        });
        
        hook.testBeforeSwap(user, poolKey, params, "");
        
        // Should still be the same auction
        bytes32 secondAuctionId = hook.activeAuctions(poolId);
        assertEq(firstAuctionId, secondAuctionId);
    }
    
    /*//////////////////////////////////////////////////////////////
                            PRICE CALCULATION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_GetPoolPrice_WithSqrtPrice() public {
        // Set a mock sqrt price
        uint160 sqrtPriceX96 = 79228162514264337593543950336; // sqrt(1e18) * 2^96
        hook.setMockSqrtPrice(poolKey, sqrtPriceX96);
        
        uint256 price = hook.testGetPoolPrice(poolKey);
        // Should return 1e18 (1:1 ratio)
        assertEq(price, 1e18);
    }
    
    function test_GetPoolPrice_ZeroSqrtPrice() public {
        // Set zero sqrt price - should fallback to oracle
        hook.setMockSqrtPrice(poolKey, 0);
        priceOracle.setPrice(token0, token1, 2500e18);
        
        uint256 price = hook.testGetPoolPrice(poolKey);
        assertEq(price, 2500e18);
    }
    
    function test_ShouldInvertPrice_USDCStablecoin() public {
        // Test with USDC as token1 - should not invert
        bool shouldInvert = hook.testShouldInvertPrice(WETH, USDC);
        assertFalse(shouldInvert);
    }
    
    function test_ShouldInvertPrice_USDCAsToken0() public {
        // Test with USDC as token0 - should invert
        bool shouldInvert = hook.testShouldInvertPrice(USDC, WETH);
        assertTrue(shouldInvert);
    }
    
    function test_ShouldInvertPrice_USDTStablecoin() public {
        // Test with USDT as token1 - should not invert
        bool shouldInvert = hook.testShouldInvertPrice(WETH, USDT);
        assertFalse(shouldInvert);
    }
    
    function test_ShouldInvertPrice_USDTAsToken0() public {
        // Test with USDT as token0 - should invert
        bool shouldInvert = hook.testShouldInvertPrice(USDT, WETH);
        assertTrue(shouldInvert);
    }
    
    function test_ShouldInvertPrice_DAIStablecoin() public {
        // Test with DAI as token1 - should not invert
        bool shouldInvert = hook.testShouldInvertPrice(WETH, DAI);
        assertFalse(shouldInvert);
    }
    
    function test_ShouldInvertPrice_DAIAsToken0() public {
        // Test with DAI as token0 - should invert
        bool shouldInvert = hook.testShouldInvertPrice(DAI, WETH);
        assertTrue(shouldInvert);
    }
    
    function test_ShouldInvertPrice_AddressOrdering() public {
        // Test with non-stablecoin tokens - should use address ordering
        Currency lower = Currency.wrap(address(0x100));
        Currency higher = Currency.wrap(address(0x200));
        
        bool shouldInvert = hook.testShouldInvertPrice(lower, higher);
        assertTrue(shouldInvert); // lower < higher, so invert
        
        shouldInvert = hook.testShouldInvertPrice(higher, lower);
        assertFalse(shouldInvert); // higher > lower, so don't invert
    }
    
    /*//////////////////////////////////////////////////////////////
                            MEV DISTRIBUTION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_MEVDistribution() public {
        // Authorize operator and create auction
        vm.prank(owner);
        hook.setOperatorAuthorization(operator, true);
        
        _createActiveAuction();
        bytes32 auctionId = hook.activeAuctions(poolId);
        
        // Fast forward past auction end
        vm.warp(block.timestamp + hook.MAX_AUCTION_DURATION() + 1);
        
        uint256 winningBid = 10 ether;
        
        vm.expectEmit(true, false, false, true);
        emit AuctionEnded(auctionId, poolId, winner, winningBid);
        
        vm.expectEmit(true, false, false, true);
        emit MEVDistributed(poolId, winningBid, 8500000000000000000, 1000000000000000000, 300000000000000000);
        
        vm.prank(operator);
        hook.submitAuctionResult(auctionId, winner, winningBid);
        
        // Check distribution amounts
        uint256 lpAmount = (winningBid * hook.LP_REWARD_PERCENTAGE()) / hook.BASIS_POINTS();
        uint256 avsAmount = (winningBid * hook.AVS_REWARD_PERCENTAGE()) / hook.BASIS_POINTS();
        uint256 protocolAmount = (winningBid * hook.PROTOCOL_FEE_PERCENTAGE()) / hook.BASIS_POINTS();
        
        assertEq(lpAmount, 8500000000000000000); // 85%
        assertEq(avsAmount, 1000000000000000000); // 10%
        assertEq(protocolAmount, 300000000000000000); // 3%
        
        // Check pool rewards updated
        assertEq(hook.poolRewards(poolId), lpAmount);
        
        // Check operator received AVS reward
        assertEq(operator.balance, 5 ether + avsAmount);
        
        // Check fee recipient received protocol fee
        assertEq(feeRecipient.balance, 1 ether + protocolAmount);
    }
    
    function test_MEVDistribution_ZeroBid() public {
        // Authorize operator and create auction
        vm.prank(owner);
        hook.setOperatorAuthorization(operator, true);
        
        _createActiveAuction();
        bytes32 auctionId = hook.activeAuctions(poolId);
        
        vm.warp(block.timestamp + hook.MAX_AUCTION_DURATION() + 1);
        
        // Submit zero bid
        vm.prank(operator);
        hook.submitAuctionResult(auctionId, winner, 0);
        
        // No distribution should occur
        assertEq(hook.poolRewards(poolId), 0);
        assertEq(operator.balance, 5 ether);
        assertEq(feeRecipient.balance, 1 ether);
    }
    
    /*//////////////////////////////////////////////////////////////
                            OVERFLOW PROTECTION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_PriceDeviation_OverflowProtection() public {
        // Test with extreme price difference that could cause overflow
        hook.setMockPoolPrice(poolKey, 1e18);
        priceOracle.setPrice(token0, token1, type(uint256).max / 2);
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 2e18,
            sqrtPriceLimitX96: 0
        });
        
        // Should not revert due to overflow protection
        hook.testBeforeSwap(user, poolKey, params, "");
        
        // Should create auction due to extreme deviation
        bytes32 auctionId = hook.activeAuctions(poolId);
        assertTrue(auctionId != bytes32(0));
    }
    
    function test_SqrtPriceConversion_OverflowProtection() public {
        // Test sqrt price conversion with potential overflow
        uint160 maxSqrtPrice = type(uint160).max;
        hook.setMockSqrtPrice(poolKey, maxSqrtPrice);
        
        uint256 price = hook.testGetPoolPrice(poolKey);
        // Should handle overflow gracefully
        assertTrue(price > 0);
    }
    
    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    function _createActiveAuction() internal {
        // Set mock pool price
        hook.setMockPoolPrice(poolKey, 2000e18);
        
        // Set oracle price to create 5% deviation
        priceOracle.setPrice(token0, token1, 2100e18);
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 2e18,
            sqrtPriceLimitX96: 0
        });
        
        hook.testBeforeSwap(user, poolKey, params, "");
    }
    
    /*//////////////////////////////////////////////////////////////
                            EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_AuctionWithZeroPrices() public {
        // Set zero prices
        hook.setMockPoolPrice(poolKey, 0);
        priceOracle.setPrice(token0, token1, 0);
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 2e18,
            sqrtPriceLimitX96: 0
        });
        
        hook.testBeforeSwap(user, poolKey, params, "");
        
        // Should not create auction with zero prices
        bytes32 auctionId = hook.activeAuctions(poolId);
        assertEq(auctionId, bytes32(0));
    }
    
    function test_AuctionWithMaxUint256Prices() public {
        // Set max uint256 prices
        hook.setMockPoolPrice(poolKey, type(uint256).max);
        priceOracle.setPrice(token0, token1, type(uint256).max);
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 2e18,
            sqrtPriceLimitX96: 0
        });
        
        hook.testBeforeSwap(user, poolKey, params, "");
        
        // Should not create auction with same max prices
        bytes32 auctionId = hook.activeAuctions(poolId);
        assertEq(auctionId, bytes32(0));
    }
    
    function test_NegativeAmountSpecified() public {
        // Test with negative amount (selling token1 for token0)
        hook.setMockPoolPrice(poolKey, 2000e18);
        priceOracle.setPrice(token0, token1, 2100e18);
        
        SwapParams memory params = SwapParams({
            zeroForOne: false,
            amountSpecified: -2e18, // Negative amount
            sqrtPriceLimitX96: 0
        });
        
        hook.testBeforeSwap(user, poolKey, params, "");
        
        // Should create auction for significant negative swap
        bytes32 auctionId = hook.activeAuctions(poolId);
        assertTrue(auctionId != bytes32(0));
    }
}
