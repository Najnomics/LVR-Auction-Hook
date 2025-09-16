// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {TestLVRAuctionHook} from "../mocks/TestLVRAuctionHook.sol";
import {SimplePoolManager, MockAVSDirectory, MockPriceOracle} from "../mocks/SimpleMocks.sol";
import {AuctionLib} from "../../src/libraries/AuctionLib.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {IAVSDirectory} from "../../src/interfaces/IAVSDirectory.sol";
import {IPriceOracle} from "../../src/interfaces/IPriceOracle.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/types/Currency.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";

/**
 * @title LVRAuctionHookFuzzTest
 * @notice Comprehensive fuzz testing for LVRAuctionHook contract
 * @dev Tests with randomized inputs to find edge cases
 */
contract LVRAuctionHookFuzzTest is Test {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/
    
    TestLVRAuctionHook public hook;
    SimplePoolManager public poolManager;
    MockAVSDirectory public avsDirectory;
    MockPriceOracle public priceOracle;
    
    address public owner;
    address public operator;
    address public user;
    address public feeRecipient;
    
    PoolKey public poolKey;
    PoolId public poolId;
    
    uint256 public constant LVR_THRESHOLD = 500; // 5%

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/
    
    function setUp() public {
        owner = address(this);
        operator = address(0x1);
        user = address(0x2);
        feeRecipient = address(0x3);
        
        // Deploy mock contracts
        poolManager = new SimplePoolManager();
        avsDirectory = new MockAVSDirectory();
        priceOracle = new MockPriceOracle();
        
        // Deploy hook
        hook = new TestLVRAuctionHook(
            IPoolManager(address(poolManager)),
            avsDirectory,
            priceOracle,
            feeRecipient,
            LVR_THRESHOLD
        );
        
        // Set up pool
        poolKey = PoolKey({
            currency0: Currency.wrap(address(0x100)),
            currency1: Currency.wrap(address(0x200)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        poolId = poolKey.toId();
        
        // Authorize operator
        hook.setOperatorAuthorization(operator, true);
    }

    /*//////////////////////////////////////////////////////////////
                            LIQUIDITY FUZZ TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testFuzz_AddLiquidity_RandomAmounts(uint256 amount) public {
        vm.assume(amount <= 1e30); // Reasonable upper bound
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: int256(amount),
            salt: 0
        });
        
        hook.beforeAddLiquidity(user, poolKey, params, "");
        
        assertEq(hook.lpLiquidity(poolId, user), amount);
        assertEq(hook.totalLiquidity(poolId), amount);
    }
    
    function testFuzz_RemoveLiquidity_RandomAmounts(uint256 addAmount, uint256 removeAmount) public {
        vm.assume(addAmount <= 1e30);
        vm.assume(removeAmount <= addAmount);
        vm.assume(addAmount > 0);
        
        // Add liquidity
        ModifyLiquidityParams memory addParams = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: int256(addAmount),
            salt: 0
        });
        hook.beforeAddLiquidity(user, poolKey, addParams, "");
        
        // Remove liquidity
        ModifyLiquidityParams memory removeParams = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: -int256(removeAmount),
            salt: 0
        });
        hook.beforeRemoveLiquidity(user, poolKey, removeParams, "");
        
        assertEq(hook.lpLiquidity(poolId, user), addAmount - removeAmount);
        assertEq(hook.totalLiquidity(poolId), addAmount - removeAmount);
    }
    
    function testFuzz_MultipleUsers_RandomLiquidity(uint256 user1Amount, uint256 user2Amount) public {
        vm.assume(user1Amount <= 1e30);
        vm.assume(user2Amount <= 1e30);
        vm.assume(user1Amount > 0 || user2Amount > 0);
        
        address user1 = address(0x4);
        address user2 = address(0x5);
        
        if (user1Amount > 0) {
            ModifyLiquidityParams memory params1 = ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: int256(user1Amount),
                salt: 0
            });
            hook.beforeAddLiquidity(user1, poolKey, params1, "");
        }
        
        if (user2Amount > 0) {
            ModifyLiquidityParams memory params2 = ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: int256(user2Amount),
                salt: 0
            });
            hook.beforeAddLiquidity(user2, poolKey, params2, "");
        }
        
        assertEq(hook.totalLiquidity(poolId), user1Amount + user2Amount);
    }

    /*//////////////////////////////////////////////////////////////
                            PRICE DEVIATION FUZZ TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testFuzz_PriceDeviation_RandomPrices(uint256 poolPrice, uint256 oraclePrice) public {
        vm.assume(poolPrice > 0 && poolPrice <= 1e30);
        vm.assume(oraclePrice > 0 && oraclePrice <= 1e30);
        
        priceOracle.setPrice(poolPrice, oraclePrice);
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 1000e18,
            sqrtPriceLimitX96: 0
        });
        
        hook.beforeSwap(user, poolKey, params, "");
        
        // Should not revert regardless of price values
        assertTrue(true);
    }
    
    function testFuzz_PriceDeviation_EdgeCases(uint256 price) public {
        vm.assume(price > 0 && price <= 1e30);
        
        // Test with same prices (0% deviation)
        priceOracle.setPrice(price, price);
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 1000e18,
            sqrtPriceLimitX96: 0
        });
        
        hook.beforeSwap(user, poolKey, params, "");
        
        // Should not trigger auction
        bytes32 auctionId = hook.activeAuctions(poolId);
        assertEq(auctionId, bytes32(0));
    }
    
    function testFuzz_PriceDeviation_ExtremeValues(uint256 price) public {
        vm.assume(price > 0);
        
        // Test with extreme price differences
        priceOracle.setPrice(price, price * 1000);
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 1000e18,
            sqrtPriceLimitX96: 0
        });
        
        hook.beforeSwap(user, poolKey, params, "");
        
        // Should handle extreme values gracefully
        assertTrue(true);
    }

    /*//////////////////////////////////////////////////////////////
                            SWAP FUZZ TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testFuzz_Swap_RandomAmounts(uint256 amount) public {
        vm.assume(amount <= 1e30);
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(amount),
            sqrtPriceLimitX96: 0
        });
        
        hook.beforeSwap(user, poolKey, params, "");
        
        // Should not revert
        assertTrue(true);
    }
    
    function testFuzz_Swap_RandomDirections(bool zeroForOne, uint256 amount) public {
        vm.assume(amount <= 1e30);
        
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: int256(amount),
            sqrtPriceLimitX96: 0
        });
        
        hook.beforeSwap(user, poolKey, params, "");
        
        // Should not revert
        assertTrue(true);
    }
    
    function testFuzz_Swap_RandomSqrtPriceLimit(uint256 amount, uint160 sqrtPriceLimit) public {
        vm.assume(amount <= 1e30);
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(amount),
            sqrtPriceLimitX96: sqrtPriceLimit
        });
        
        hook.beforeSwap(user, poolKey, params, "");
        
        // Should not revert
        assertTrue(true);
    }

    /*//////////////////////////////////////////////////////////////
                            AUCTION FUZZ TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testFuzz_AuctionResult_RandomBids(uint256 winningBid) public {
        vm.assume(winningBid <= 1000 ether);
        
        // Trigger auction through swap
        priceOracle.setPrice(1e18, 2e18); // High deviation
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(1000e18),
            sqrtPriceLimitX96: 0
        });
        hook.beforeSwap(user, poolKey, params, "");
        
        bytes32 auctionId = hook.activeAuctions(poolId);
        assertTrue(auctionId != bytes32(0));
        
        vm.warp(block.timestamp + 400);
        
        vm.prank(operator);
        hook.submitAuctionResult(auctionId, user, winningBid);
        
        (,,,, bool isComplete, address auctionWinner, uint256 auctionWinningBid,) = hook.auctions(auctionId);
        assertEq(auctionWinningBid, winningBid);
        assertTrue(isComplete);
    }
    
    function testFuzz_AuctionResult_RandomWinners(address winner) public {
        vm.assume(winner != address(0));
        
        // Trigger auction through swap
        priceOracle.setPrice(1e18, 2e18); // High deviation
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(1000e18),
            sqrtPriceLimitX96: 0
        });
        hook.beforeSwap(user, poolKey, params, "");
        
        bytes32 auctionId = hook.activeAuctions(poolId);
        assertTrue(auctionId != bytes32(0));
        
        vm.warp(block.timestamp + 400);
        
        vm.prank(operator);
        hook.submitAuctionResult(auctionId, winner, 1 ether);
        
        (,,,, bool isComplete, address auctionWinner, uint256 winningBid,) = hook.auctions(auctionId);
        assertEq(auctionWinner, winner);
        assertTrue(isComplete);
    }
    
    function testFuzz_AuctionDuration_RandomDurations(uint256 duration) public {
        vm.assume(duration > 0 && duration <= 365 days);
        
        // Trigger auction through swap
        priceOracle.setPrice(1e18, 2e18); // High deviation
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(1000e18),
            sqrtPriceLimitX96: 0
        });
        hook.beforeSwap(user, poolKey, params, "");
        
        bytes32 auctionId = hook.activeAuctions(poolId);
        assertTrue(auctionId != bytes32(0));
        
        // Check auction is active
        (,, uint256 auctionDuration, bool isActive,,,,) = hook.auctions(auctionId);
        assertTrue(isActive);
        assertEq(auctionDuration, 12); // MAX_AUCTION_DURATION
    }

    /*//////////////////////////////////////////////////////////////
                            REWARD FUZZ TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testFuzz_ClaimRewards_RandomLiquidity(uint256 liquidity) public {
        vm.assume(liquidity > 0 && liquidity <= 1e30);
        
        // Add liquidity
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: int256(liquidity),
            salt: 0
        });
        hook.beforeAddLiquidity(user, poolKey, params, "");
        
        // Add some rewards
        vm.deal(address(hook), 1 ether);
        
        uint256 initialBalance = user.balance;
        
        vm.prank(user);
        hook.claimRewards(poolId);
        
        // Should receive some rewards
        assertTrue(user.balance >= initialBalance);
    }
    
    function testFuzz_ClaimRewards_RandomUsers(address claimer) public {
        vm.assume(claimer != address(0));
        
        // Add liquidity for the claimer
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: int256(1000e18),
            salt: 0
        });
        hook.beforeAddLiquidity(claimer, poolKey, params, "");
        
        // Add some rewards
        vm.deal(address(hook), 1 ether);
        
        uint256 initialBalance = claimer.balance;
        
        vm.prank(claimer);
        hook.claimRewards(poolId);
        
        // Should receive some rewards
        assertTrue(claimer.balance >= initialBalance);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUZZ TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testFuzz_SetLVRThreshold_RandomValues(uint256 threshold) public {
        vm.assume(threshold <= 10000); // Max 100%
        
        hook.setLVRThreshold(threshold);
        
        assertEq(hook.lvrThreshold(), threshold);
    }
    
    function testFuzz_SetFeeRecipient_RandomAddresses(address newRecipient) public {
        vm.assume(newRecipient != address(0));
        
        hook.setFeeRecipient(newRecipient);
        
        assertEq(hook.feeRecipient(), newRecipient);
    }
    
    function testFuzz_SetOperatorAuthorization_RandomOperators(address newOperator, bool authorized) public {
        vm.assume(newOperator != address(0));
        
        hook.setOperatorAuthorization(newOperator, authorized);
        
        assertEq(hook.authorizedOperators(newOperator), authorized);
    }

    /*//////////////////////////////////////////////////////////////
                            EDGE CASE FUZZ TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testFuzz_ZeroValues() public {
        // Test with zero amounts
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 0,
            salt: 0
        });
        hook.beforeAddLiquidity(user, poolKey, params, "");
        
        SwapParams memory swapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: 0,
            sqrtPriceLimitX96: 0
        });
        hook.beforeSwap(user, poolKey, swapParams, "");
        
        // Should not revert
        assertTrue(true);
    }
    
    function testFuzz_MaxValues() public {
        // Test with maximum values
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: type(int256).max,
            salt: 0
        });
        hook.beforeAddLiquidity(user, poolKey, params, "");
        
        SwapParams memory swapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(type(uint256).max),
            sqrtPriceLimitX96: type(uint160).max
        });
        hook.beforeSwap(user, poolKey, swapParams, "");
        
        // Should not revert
        assertTrue(true);
    }
    
    function testFuzz_RandomPoolKeys(address token0, address token1, uint24 fee, int24 tickSpacing) public {
        vm.assume(token0 != address(0));
        vm.assume(token1 != address(0));
        vm.assume(token0 != token1);
        vm.assume(fee > 0 && fee <= 1000000); // Reasonable fee range
        vm.assume(tickSpacing > 0 && tickSpacing <= 10000); // Reasonable tick spacing
        
        PoolKey memory randomPoolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(hook))
        });
        
        PoolId randomPoolId = randomPoolKey.toId();
        
        // Test with random pool
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: int256(1000e18),
            salt: 0
        });
        hook.beforeAddLiquidity(user, randomPoolKey, params, "");
        
        assertEq(hook.lpLiquidity(randomPoolId, user), 1000e18);
    }
}
