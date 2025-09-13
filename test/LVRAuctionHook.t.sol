// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {PoolId} from "@uniswap/v4-core/types/PoolId.sol";

import {LVRAuctionHook} from "../src/LVRAuctionHook.sol";
import {LVRAuctionServiceManager} from "../src/LVRAuctionServiceManager.sol";
import {ChainlinkPriceOracle} from "../src/ChainlinkPriceOracle.sol";
import {ProductionPriceFeedConfig} from "../src/ProductionPriceFeedConfig.sol";
import {IAVSDirectory} from "../src/interfaces/IAVSDirectory.sol";
import {IPriceOracle} from "../src/interfaces/IPriceOracle.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/libraries/Hooks.sol";

/**
 * @title LVRAuctionHookTest
 * @notice Comprehensive test suite for LVR Auction Hook
 */
contract LVRAuctionHookTest is Test {
    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/
    
    LVRAuctionHook public hook;
    LVRAuctionServiceManager public serviceManager;
    ChainlinkPriceOracle public priceOracle;
    ProductionPriceFeedConfig public priceFeedConfig;
    
    address public owner;
    address public feeRecipient;
    address public operator;
    address public lp;
    
    // Mock addresses
    address public constant POOL_MANAGER = address(0x1);
    address public constant AVS_DIRECTORY = address(0x2);
    
    // Test tokens
    Currency public token0;
    Currency public token1;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/
    
    function setUp() public {
        owner = address(this);
        feeRecipient = address(0x3);
        operator = address(0x4);
        lp = address(0x5);
        
        // Create test tokens
        token0 = Currency.wrap(makeAddr("token0"));
        token1 = Currency.wrap(makeAddr("token1"));
        
        // Deploy contracts
        vm.etch(AVS_DIRECTORY, address(new MockAVSDirectory()).code);
        vm.etch(POOL_MANAGER, address(new MockPoolManager()).code);
        
        priceOracle = new ChainlinkPriceOracle(owner);
        serviceManager = new LVRAuctionServiceManager(IAVSDirectory(AVS_DIRECTORY));
        
        hook = new LVRAuctionHook(
            IPoolManager(POOL_MANAGER),
            IAVSDirectory(AVS_DIRECTORY),
            IPriceOracle(address(priceOracle)),
            feeRecipient,
            50 // 0.5% threshold
        );
        
        priceFeedConfig = new ProductionPriceFeedConfig();
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testConstructor() public {
        assertEq(address(hook.avsDirectory()), AVS_DIRECTORY);
        assertEq(address(hook.priceOracle()), address(priceOracle));
        assertEq(hook.feeRecipient(), feeRecipient);
        assertEq(hook.lvrThreshold(), 50);
        assertEq(hook.owner(), owner);
    }
    
    function testHookPermissions() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        
        assertFalse(permissions.beforeInitialize);
        assertFalse(permissions.afterInitialize);
        assertTrue(permissions.beforeAddLiquidity);
        assertFalse(permissions.afterAddLiquidity);
        assertTrue(permissions.beforeRemoveLiquidity);
        assertFalse(permissions.afterRemoveLiquidity);
        assertTrue(permissions.beforeSwap);
        assertTrue(permissions.afterSwap);
        assertFalse(permissions.beforeDonate);
        assertFalse(permissions.afterDonate);
    }
    
    function testSetOperatorAuthorization() public {
        // Initially unauthorized
        assertFalse(hook.authorizedOperators(operator));
        
        // Authorize operator
        hook.setOperatorAuthorization(operator, true);
        assertTrue(hook.authorizedOperators(operator));
        
        // Deauthorize operator
        hook.setOperatorAuthorization(operator, false);
        assertFalse(hook.authorizedOperators(operator));
    }
    
    function testSetLVRThreshold() public {
        uint256 oldThreshold = hook.lvrThreshold();
        uint256 newThreshold = 100;
        
        hook.setLVRThreshold(newThreshold);
        assertEq(hook.lvrThreshold(), newThreshold);
        
        // Test event emission
        vm.expectEmit(true, true, true, true);
        emit LVRThresholdUpdated(oldThreshold, newThreshold);
        hook.setLVRThreshold(150);
    }
    
    function testSetFeeRecipient() public {
        address newFeeRecipient = address(0x6);
        
        hook.setFeeRecipient(newFeeRecipient);
        assertEq(hook.feeRecipient(), newFeeRecipient);
    }
    
    function testPauseUnpause() public {
        // Initially not paused
        assertFalse(hook.paused());
        
        // Pause
        hook.pause();
        assertTrue(hook.paused());
        
        // Unpause
        hook.unpause();
        assertFalse(hook.paused());
    }
    
    function testConstants() public {
        assertEq(hook.MIN_BID(), 1e15);
        assertEq(hook.MAX_AUCTION_DURATION(), 12);
        assertEq(hook.LP_REWARD_PERCENTAGE(), 8500);
        assertEq(hook.AVS_REWARD_PERCENTAGE(), 1000);
        assertEq(hook.PROTOCOL_FEE_PERCENTAGE(), 300);
        assertEq(hook.GAS_COMPENSATION_PERCENTAGE(), 200);
        assertEq(hook.BASIS_POINTS(), 10000);
    }
    
    function testReceiveETH() public {
        uint256 initialBalance = address(hook).balance;
        uint256 sendAmount = 1 ether;
        
        vm.deal(address(this), sendAmount);
        (bool success,) = address(hook).call{value: sendAmount}("");
        
        assertTrue(success);
        assertEq(address(hook).balance, initialBalance + sendAmount);
    }
    
    function testFailSetLVRThresholdTooHigh() public {
        hook.setLVRThreshold(1001); // Should fail as max is 1000 (10%)
    }
    
    function testFailSetFeeRecipientZeroAddress() public {
        hook.setFeeRecipient(address(0));
    }
    
    function testFailUnauthorizedOperator() public {
        vm.prank(operator);
        hook.submitAuctionResult(bytes32(0), address(0), 0);
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event OperatorAuthorized(address indexed operator, bool authorized);
    event LVRThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event AuctionStarted(bytes32 indexed auctionId, PoolId indexed poolId, uint256 startTime, uint256 duration);
    event AuctionEnded(bytes32 indexed auctionId, PoolId indexed poolId, address indexed winner, uint256 winningBid);
    event MEVDistributed(PoolId indexed poolId, uint256 totalAmount, uint256 lpAmount, uint256 avsAmount, uint256 protocolAmount);
    event RewardsClaimed(PoolId indexed poolId, address indexed lp, uint256 amount);
}

/*//////////////////////////////////////////////////////////////
                            MOCK CONTRACTS
//////////////////////////////////////////////////////////////*/

contract MockAVSDirectory {
    function registerOperatorToAVS(address, bytes calldata) external pure {}
    function deregisterOperatorFromAVS(address) external pure {}
    function isOperatorRegistered(address, address) external pure returns (bool) { return true; }
    function getOperatorStake(address, address) external pure returns (uint256) { return 32 ether; }
}

contract MockPoolManager {
    function getSlot0(bytes32) external pure returns (uint160, int24, uint24, uint24) {
        return (0, 0, 0, 0);
    }
}
