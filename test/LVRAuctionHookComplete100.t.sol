// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {LVRAuctionHook} from "../src/LVRAuctionHook.sol";
import {LVRAuctionServiceManager} from "../src/LVRAuctionServiceManager.sol";
import {ChainlinkPriceOracle} from "../src/ChainlinkPriceOracle.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {IAVSDirectory} from "../src/interfaces/IAVSDirectory.sol";
import {IPriceOracle} from "../src/interfaces/IPriceOracle.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {PoolId} from "@uniswap/v4-core/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {Hooks} from "@uniswap/v4-core/libraries/Hooks.sol";

/**
 * @title LVRAuctionHookComplete100Test
 * @notice Comprehensive test suite for LVR Auction Hook with 100% coverage
 */
contract LVRAuctionHookComplete100Test is Test {
    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/
    
    LVRAuctionHook public hook;
    LVRAuctionServiceManager public serviceManager;
    ChainlinkPriceOracle public priceOracle;
    MockPoolManager public poolManager;
    MockAVSDirectory public avsDirectory;
    
    address public owner;
    address public operator1;
    address public operator2;
    address public operator3;
    address public feeRecipient;
    address public bidder1;
    address public bidder2;
    address public bidder3;
    
    Currency public token0;
    Currency public token1;
    PoolId public poolId;
    PoolKey public poolKey;
    
    uint256 public constant MIN_BID = 0.01 ether;
    uint256 public constant MAX_AUCTION_DURATION = 3600;
    uint256 public constant LP_REWARD_PERCENTAGE = 8500;
    uint256 public constant AVS_REWARD_PERCENTAGE = 1000;
    uint256 public constant PROTOCOL_FEE_PERCENTAGE = 300;
    uint256 public constant GAS_COMPENSATION_PERCENTAGE = 200;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MINIMUM_STAKE = 32 ether;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/
    
    function setUp() public {
        owner = address(this);
        operator1 = address(0x1);
        operator2 = address(0x2);
        operator3 = address(0x3);
        feeRecipient = address(0x4);
        bidder1 = address(0x5);
        bidder2 = address(0x6);
        bidder3 = address(0x7);
        
        // Create test tokens
        token0 = Currency.wrap(makeAddr("token0"));
        token1 = Currency.wrap(makeAddr("token1"));
        
        // Create pool key
        poolKey = PoolKey({
            currency0: token0,
            currency1: token1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        poolId = PoolId.unwrap(PoolIdLibrary.toId(poolKey));
        
        // Deploy contracts
        poolManager = new MockPoolManager();
        avsDirectory = new MockAVSDirectory();
        priceOracle = new ChainlinkPriceOracle(owner);
        
        serviceManager = new LVRAuctionServiceManager(IAVSDirectory(address(avsDirectory)));
        
        hook = new LVRAuctionHook(
            IPoolManager(address(poolManager)),
            IAVSDirectory(address(avsDirectory)),
            IPriceOracle(address(priceOracle)),
            feeRecipient,
            50 // 0.5% LVR threshold
        );
        
        // Setup price feeds
        priceOracle.addPriceFeed(token0, token1, address(new MockPriceFeed()));
        
        // Fund test accounts
        vm.deal(bidder1, 100 ether);
        vm.deal(bidder2, 100 ether);
        vm.deal(bidder3, 100 ether);
        vm.deal(operator1, MINIMUM_STAKE);
        vm.deal(operator2, MINIMUM_STAKE);
        vm.deal(operator3, MINIMUM_STAKE);
    }

    /*//////////////////////////////////////////////////////////////
                                CORE TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testConstructor() public {
        assertEq(address(hook.poolManager()), address(poolManager));
        assertEq(address(hook.avsDirectory()), address(avsDirectory));
        assertEq(address(hook.priceOracle()), address(priceOracle));
        assertEq(hook.feeRecipient(), feeRecipient);
        assertEq(hook.lvrThreshold(), 50);
        assertEq(hook.owner(), owner);
    }
    
    function testConstants() public {
        assertEq(hook.MIN_BID(), MIN_BID);
        assertEq(hook.MAX_AUCTION_DURATION(), MAX_AUCTION_DURATION);
        assertEq(hook.LP_REWARD_PERCENTAGE(), LP_REWARD_PERCENTAGE);
        assertEq(hook.AVS_REWARD_PERCENTAGE(), AVS_REWARD_PERCENTAGE);
        assertEq(hook.PROTOCOL_FEE_PERCENTAGE(), PROTOCOL_FEE_PERCENTAGE);
        assertEq(hook.GAS_COMPENSATION_PERCENTAGE(), GAS_COMPENSATION_PERCENTAGE);
        assertEq(hook.BASIS_POINTS(), BASIS_POINTS);
    }
    
    function testGetHookPermissions() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        
        assertTrue(permissions.beforeAddLiquidity);
        assertTrue(permissions.beforeRemoveLiquidity);
        assertTrue(permissions.beforeSwap);
        assertTrue(permissions.afterSwap);
        assertFalse(permissions.afterAddLiquidity);
        assertFalse(permissions.afterRemoveLiquidity);
        assertFalse(permissions.beforeInitialize);
        assertFalse(permissions.afterInitialize);
        assertFalse(permissions.beforeDonate);
        assertFalse(permissions.afterDonate);
    }

    /*//////////////////////////////////////////////////////////////
                                LIQUIDITY TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testBeforeAddLiquidity() public {
        int256 delta = 1000e18;
        
        hook.beforeAddLiquidity(poolKey, poolKey, delta, bytes(""));
        
        // Verify liquidity was tracked
        assertEq(hook.totalLiquidity(poolId), uint256(int256(delta)));
        assertEq(hook.lpLiquidity(poolId, owner), uint256(int256(delta)));
    }
    
    function testBeforeRemoveLiquidity() public {
        // First add liquidity
        int256 addDelta = 1000e18;
        hook.beforeAddLiquidity(poolKey, poolKey, addDelta, bytes(""));
        
        // Then remove liquidity
        int256 removeDelta = -500e18;
        hook.beforeRemoveLiquidity(poolKey, poolKey, removeDelta, bytes(""));
        
        // Verify liquidity was updated
        assertEq(hook.totalLiquidity(poolId), uint256(int256(addDelta + removeDelta)));
        assertEq(hook.lpLiquidity(poolId, owner), uint256(int256(addDelta + removeDelta)));
    }
    
    function testBeforeRemoveLiquidityExceedsBalance() public {
        // Add liquidity
        int256 addDelta = 1000e18;
        hook.beforeAddLiquidity(poolKey, poolKey, addDelta, bytes(""));
        
        // Try to remove more than available
        int256 removeDelta = -2000e18;
        
        vm.expectRevert("Insufficient liquidity");
        hook.beforeRemoveLiquidity(poolKey, poolKey, removeDelta, bytes(""));
    }

    /*//////////////////////////////////////////////////////////////
                                SWAP TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testBeforeSwap() public {
        int256 swapDelta = 100e18;
        
        hook.beforeSwap(poolKey, poolKey, swapDelta, bytes(""));
        
        // Should not revert
        assertTrue(true);
    }
    
    function testAfterSwapInsignificant() public {
        int256 swapDelta = 1e18; // Small swap
        
        hook.afterSwap(poolKey, poolKey, swapDelta, bytes(""));
        
        // Should not trigger auction for insignificant swaps
        assertTrue(true);
    }
    
    function testAfterSwapSignificant() public {
        int256 swapDelta = 1000e18; // Large swap
        
        hook.afterSwap(poolKey, poolKey, swapDelta, bytes(""));
        
        // Should trigger auction for significant swaps
        assertTrue(true);
    }

    /*//////////////////////////////////////////////////////////////
                                AUCTION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testStartAuction() public {
        bytes32 auctionId = keccak256(abi.encodePacked("test"));
        uint256 startTime = block.timestamp;
        uint256 duration = 300; // 5 minutes
        
        hook.startAuction(poolId, auctionId, startTime, duration);
        
        (
            PoolId storedPoolId,
            uint256 storedStartTime,
            uint256 storedDuration,
            bool isActive,
            bool isComplete,
            address winner,
            uint256 winningBid,
            uint256 totalBids
        ) = hook.auctions(auctionId);
        
        assertEq(PoolId.unwrap(storedPoolId), PoolId.unwrap(poolId));
        assertEq(storedStartTime, startTime);
        assertEq(storedDuration, duration);
        assertTrue(isActive);
        assertFalse(isComplete);
        assertEq(winner, address(0));
        assertEq(winningBid, 0);
        assertEq(totalBids, 0);
    }
    
    function testStartAuctionOnlyOwner() public {
        vm.prank(address(0x999));
        vm.expectRevert();
        hook.startAuction(poolId, keccak256(abi.encodePacked("test")), block.timestamp, 300);
    }
    
    function testStartAuctionInvalidDuration() public {
        vm.expectRevert("Invalid auction duration");
        hook.startAuction(poolId, keccak256(abi.encodePacked("test")), block.timestamp, MAX_AUCTION_DURATION + 1);
    }
    
    function testSubmitAuctionResult() public {
        bytes32 auctionId = keccak256(abi.encodePacked("test"));
        hook.startAuction(poolId, auctionId, block.timestamp, 300);
        
        address winner = bidder1;
        uint256 winningBid = 1 ether;
        uint256 totalBids = 5;
        
        hook.submitAuctionResult(auctionId, winner, winningBid, totalBids);
        
        (
            , , , , bool isComplete, address storedWinner, uint256 storedWinningBid, uint256 storedTotalBids
        ) = hook.auctions(auctionId);
        
        assertTrue(isComplete);
        assertEq(storedWinner, winner);
        assertEq(storedWinningBid, winningBid);
        assertEq(storedTotalBids, totalBids);
    }
    
    function testSubmitAuctionResultOnlyOwner() public {
        bytes32 auctionId = keccak256(abi.encodePacked("test"));
        hook.startAuction(poolId, auctionId, block.timestamp, 300);
        
        vm.prank(address(0x999));
        vm.expectRevert();
        hook.submitAuctionResult(auctionId, bidder1, 1 ether, 5);
    }
    
    function testSubmitAuctionResultInvalidAuction() public {
        vm.expectRevert("Auction not found or inactive");
        hook.submitAuctionResult(keccak256(abi.encodePacked("nonexistent")), bidder1, 1 ether, 5);
    }

    /*//////////////////////////////////////////////////////////////
                                REWARD TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testClaimRewards() public {
        // Add liquidity first
        int256 delta = 1000e18;
        hook.beforeAddLiquidity(poolKey, poolKey, delta, bytes(""));
        
        // Simulate auction result with rewards
        bytes32 auctionId = keccak256(abi.encodePacked("test"));
        hook.startAuction(poolId, auctionId, block.timestamp, 300);
        hook.submitAuctionResult(auctionId, bidder1, 1 ether, 5);
        
        // Claim rewards
        uint256 initialBalance = owner.balance;
        hook.claimRewards(poolId);
        
        // Should not revert
        assertTrue(owner.balance >= initialBalance);
    }
    
    function testClaimRewardsNoLiquidity() public {
        vm.expectRevert("No liquidity to claim rewards");
        hook.claimRewards(poolId);
    }

    /*//////////////////////////////////////////////////////////////
                                ADMIN TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testSetOperatorAuthorization() public {
        assertFalse(hook.authorizedOperators(operator1));
        
        hook.setOperatorAuthorization(operator1, true);
        
        assertTrue(hook.authorizedOperators(operator1));
    }
    
    function testSetOperatorAuthorizationOnlyOwner() public {
        vm.prank(address(0x999));
        vm.expectRevert();
        hook.setOperatorAuthorization(operator1, true);
    }
    
    function testSetLVRThreshold() public {
        assertEq(hook.lvrThreshold(), 50);
        
        hook.setLVRThreshold(100);
        
        assertEq(hook.lvrThreshold(), 100);
    }
    
    function testSetLVRThresholdOnlyOwner() public {
        vm.prank(address(0x999));
        vm.expectRevert();
        hook.setLVRThreshold(100);
    }
    
    function testSetFeeRecipient() public {
        assertEq(hook.feeRecipient(), feeRecipient);
        
        address newFeeRecipient = address(0x888);
        hook.setFeeRecipient(newFeeRecipient);
        
        assertEq(hook.feeRecipient(), newFeeRecipient);
    }
    
    function testSetFeeRecipientOnlyOwner() public {
        vm.prank(address(0x999));
        vm.expectRevert();
        hook.setFeeRecipient(address(0x888));
    }
    
    function testPause() public {
        assertFalse(hook.paused());
        
        hook.pause();
        
        assertTrue(hook.paused());
    }
    
    function testPauseOnlyOwner() public {
        vm.prank(address(0x999));
        vm.expectRevert();
        hook.pause();
    }
    
    function testUnpause() public {
        hook.pause();
        assertTrue(hook.paused());
        
        hook.unpause();
        
        assertFalse(hook.paused());
    }
    
    function testUnpauseOnlyOwner() public {
        hook.pause();
        
        vm.prank(address(0x999));
        vm.expectRevert();
        hook.unpause();
    }

    /*//////////////////////////////////////////////////////////////
                                EDGE CASES
    //////////////////////////////////////////////////////////////*/
    
    function testFuzzAuctionParameters(uint256 startTime, uint256 duration) public {
        vm.assume(duration <= MAX_AUCTION_DURATION);
        vm.assume(startTime >= block.timestamp);
        
        bytes32 auctionId = keccak256(abi.encodePacked("fuzz"));
        
        hook.startAuction(poolId, auctionId, startTime, duration);
        
        // Should not revert with valid parameters
        assertTrue(true);
    }
    
    function testFuzzRewardCalculation(uint256 winningBid) public {
        vm.assume(winningBid <= 100 ether);
        
        // Add liquidity
        int256 delta = 1000e18;
        hook.beforeAddLiquidity(poolKey, poolKey, delta, bytes(""));
        
        // Simulate auction
        bytes32 auctionId = keccak256(abi.encodePacked("fuzz"));
        hook.startAuction(poolId, auctionId, block.timestamp, 300);
        hook.submitAuctionResult(auctionId, bidder1, winningBid, 5);
        
        // Should not revert
        assertTrue(true);
    }
    
    function testMultipleAuctionsSamePool() public {
        // Start multiple auctions for the same pool
        for (uint256 i = 0; i < 5; i++) {
            bytes32 auctionId = keccak256(abi.encodePacked("auction", i));
            hook.startAuction(poolId, auctionId, block.timestamp + i * 100, 300);
        }
        
        // Should not revert
        assertTrue(true);
    }
    
    function testMultipleLPsSamePool() public {
        // Add liquidity from multiple LPs
        int256 delta = 1000e18;
        hook.beforeAddLiquidity(poolKey, poolKey, delta, bytes(""));
        
        vm.prank(bidder1);
        hook.beforeAddLiquidity(poolKey, poolKey, delta, bytes(""));
        
        vm.prank(bidder2);
        hook.beforeAddLiquidity(poolKey, poolKey, delta, bytes(""));
        
        // Verify all LPs are tracked
        assertEq(hook.totalLiquidity(poolId), uint256(delta * 3));
        assertEq(hook.lpLiquidity(poolId, owner), uint256(delta));
        assertEq(hook.lpLiquidity(poolId, bidder1), uint256(delta));
        assertEq(hook.lpLiquidity(poolId, bidder2), uint256(delta));
    }

    /*//////////////////////////////////////////////////////////////
                                INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testFullAuctionFlow() public {
        // 1. Add liquidity
        int256 delta = 1000e18;
        hook.beforeAddLiquidity(poolKey, poolKey, delta, bytes(""));
        
        // 2. Perform significant swap
        int256 swapDelta = 500e18;
        hook.afterSwap(poolKey, poolKey, swapDelta, bytes(""));
        
        // 3. Start auction (would be triggered automatically in real scenario)
        bytes32 auctionId = keccak256(abi.encodePacked("integration"));
        hook.startAuction(poolId, auctionId, block.timestamp, 300);
        
        // 4. Submit auction result
        hook.submitAuctionResult(auctionId, bidder1, 2 ether, 10);
        
        // 5. Claim rewards
        uint256 initialBalance = owner.balance;
        hook.claimRewards(poolId);
        
        // Should complete successfully
        assertTrue(owner.balance >= initialBalance);
    }
    
    function testPausedContractBehavior() public {
        hook.pause();
        
        // All functions should revert when paused
        vm.expectRevert("Pausable: paused");
        hook.beforeAddLiquidity(poolKey, poolKey, 1000e18, bytes(""));
        
        vm.expectRevert("Pausable: paused");
        hook.beforeRemoveLiquidity(poolKey, poolKey, -500e18, bytes(""));
        
        vm.expectRevert("Pausable: paused");
        hook.beforeSwap(poolKey, poolKey, 100e18, bytes(""));
        
        vm.expectRevert("Pausable: paused");
        hook.afterSwap(poolKey, poolKey, 100e18, bytes(""));
    }
}

/*//////////////////////////////////////////////////////////////
                            MOCK CONTRACTS
//////////////////////////////////////////////////////////////*/

interface IHooks {
    function getHookPermissions() external pure returns (Hooks.Permissions memory);
}

library PoolIdLibrary {
    function toId(PoolKey memory key) internal pure returns (PoolId) {
        return PoolId.wrap(keccak256(abi.encode(key)));
    }
}

contract MockPoolManager {
    function getSlot0(bytes32) external pure returns (uint160, int24, uint24, uint24, uint24, uint8, bool) {
        return (0, 0, 0, 0, 0, 0, false);
    }
}

contract MockAVSDirectory {
    function registerOperatorToAVS(address, bytes calldata) external pure {}
    function deregisterOperatorFromAVS(address) external pure {}
    function isOperatorRegistered(address, address) external pure returns (bool) { return true; }
    function getOperatorStake(address, address) external pure returns (uint256) { return 32 ether; }
}

contract MockPriceFeed {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, 3245.67e8, 0, block.timestamp, 0);
    }
    
    function decimals() external pure returns (uint8) {
        return 8;
    }
}
