// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {TestLVRAuctionHook} from "../mocks/TestLVRAuctionHook.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/libraries/Hooks.sol";
import {SimplePoolManager, MockAVSDirectory, MockPriceOracle} from "../mocks/SimpleMocks.sol";

contract LVRAuctionHookTest is Test {
    TestLVRAuctionHook public hook;
    SimplePoolManager public poolManager;
    MockAVSDirectory public avsDirectory;
    MockPriceOracle public priceOracle;
    
    address public owner;
    address public feeRecipient;
    address public operator;
    
    Currency public token0;
    Currency public token1;
    PoolKey public key;
    PoolId public poolId;
    
    function setUp() public {
        owner = address(this);
        feeRecipient = makeAddr("feeRecipient");
        operator = makeAddr("operator");
        
        token0 = Currency.wrap(makeAddr("token0"));
        token1 = Currency.wrap(makeAddr("token1"));
        
        poolManager = new SimplePoolManager();
        avsDirectory = new MockAVSDirectory();
        priceOracle = new MockPriceOracle();
        
        key = PoolKey({
            currency0: token0,
            currency1: token1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        poolId = key.toId();
        
        hook = new TestLVRAuctionHook(
            IPoolManager(address(poolManager)),
            avsDirectory,
            priceOracle,
            feeRecipient,
            100 // 1% threshold
        );
        
        hook.setOperatorAuthorization(operator, true);
        priceOracle.setPrice(token0, token1, 1e18);
        
        vm.deal(address(hook), 100e18);
    }
    
    function testDeployment() public view {
        assertEq(address(hook.avsDirectory()), address(avsDirectory));
        assertEq(address(hook.priceOracle()), address(priceOracle));
        assertEq(hook.feeRecipient(), feeRecipient);
        assertEq(hook.lvrThreshold(), 100);
    }
    
    function testHookPermissions() public view {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertTrue(permissions.beforeAddLiquidity);
        assertTrue(permissions.beforeRemoveLiquidity);
        assertTrue(permissions.beforeSwap);
        assertTrue(permissions.afterSwap);
    }
    
    function testOperatorAuthorization() public {
        address newOperator = makeAddr("newOperator");
        assertFalse(hook.authorizedOperators(newOperator));
        
        hook.setOperatorAuthorization(newOperator, true);
        assertTrue(hook.authorizedOperators(newOperator));
        
        hook.setOperatorAuthorization(newOperator, false);
        assertFalse(hook.authorizedOperators(newOperator));
    }
    
    function testSetLVRThreshold() public {
        hook.setLVRThreshold(200);
        assertEq(hook.lvrThreshold(), 200);
    }
    
    function testSetLVRThresholdTooHigh() public {
        vm.expectRevert("LVR Auction Hook: threshold too high");
        hook.setLVRThreshold(1001); // > 10%
    }
    
    function testSetFeeRecipient() public {
        address newRecipient = makeAddr("newRecipient");
        hook.setFeeRecipient(newRecipient);
        assertEq(hook.feeRecipient(), newRecipient);
    }
    
    function testSetFeeRecipientZeroAddress() public {
        vm.expectRevert("LVR Auction Hook: invalid address");
        hook.setFeeRecipient(address(0));
    }
    
    function testPauseUnpause() public {
        assertFalse(hook.paused());
        
        hook.pause();
        assertTrue(hook.paused());
        
        hook.unpause();
        assertFalse(hook.paused());
    }
    
    function testUnauthorizedOperatorSubmission() public {
        bytes32 auctionId = keccak256("test");
        
        vm.expectRevert("LVR Auction Hook: unauthorized operator");
        hook.submitAuctionResult(auctionId, makeAddr("winner"), 1e18);
    }
    
    function testConstants() public view {
        assertEq(hook.MIN_BID(), 1e15);
        assertEq(hook.MAX_AUCTION_DURATION(), 12);
        assertEq(hook.LP_REWARD_PERCENTAGE(), 8500);
        assertEq(hook.AVS_REWARD_PERCENTAGE(), 1000);
        assertEq(hook.PROTOCOL_FEE_PERCENTAGE(), 300);
        assertEq(hook.GAS_COMPENSATION_PERCENTAGE(), 200);
        assertEq(hook.BASIS_POINTS(), 10000);
    }
    
    function testClaimRewardsNoLiquidity() public {
        vm.expectRevert("LVR Auction Hook: no liquidity provided");
        hook.claimRewards(poolId);
    }
    
    receive() external payable {}
}