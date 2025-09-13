// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {LVRAuctionHook} from "../src/LVRAuctionHook.sol";
import {HookMiner} from "../src/utils/HookMiner.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {IAVSDirectory} from "../src/interfaces/IAVSDirectory.sol";
import {IPriceOracle} from "../src/interfaces/IPriceOracle.sol";
import {Hooks} from "@uniswap/v4-core/libraries/Hooks.sol";

/**
 * @title HookMinerTest
 * @notice Comprehensive test suite for HookMiner utility
 */
contract HookMinerTest is Test {
    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/
    
    address public deployer;
    MockPoolManager public poolManager;
    MockAVSDirectory public avsDirectory;
    MockPriceOracle public priceOracle;
    address public feeRecipient;
    uint256 public lvrThreshold;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/
    
    function setUp() public {
        deployer = address(this);
        poolManager = new MockPoolManager();
        avsDirectory = new MockAVSDirectory();
        priceOracle = new MockPriceOracle();
        feeRecipient = address(0x1234567890123456789012345678901234567890);
        lvrThreshold = 50; // 0.5%
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testComputeAddress() public {
        bytes32 salt = bytes32(uint256(12345));
        bytes memory creationCode = type(LVRAuctionHook).creationCode;
        bytes memory constructorArgs = abi.encode(
            IPoolManager(address(poolManager)),
            IAVSDirectory(address(avsDirectory)),
            IPriceOracle(address(priceOracle)),
            feeRecipient,
            lvrThreshold
        );
        bytes memory bytecode = abi.encodePacked(creationCode, constructorArgs);
        
        address computedAddr = HookMiner.computeAddress(deployer, salt, bytecode);
        
        // Verify it's a valid address
        assertTrue(computedAddr != address(0));
        
        // Test with different salt
        bytes32 salt2 = bytes32(uint256(54321));
        address computedAddr2 = HookMiner.computeAddress(deployer, salt2, bytecode);
        
        assertTrue(computedAddr != computedAddr2);
    }
    
    function testHasValidFlags() public {
        // Test address with required flags
        uint160 requiredFlags = Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG;
        address validAddr = address(uint160(requiredFlags));
        
        assertTrue(HookMiner.hasValidFlags(validAddr, requiredFlags));
        
        // Test address without required flags
        address invalidAddr = address(0x1234);
        assertFalse(HookMiner.hasValidFlags(invalidAddr, requiredFlags));
    }
    
    function testMineAddressWithFlags() public {
        bytes memory creationCode = type(LVRAuctionHook).creationCode;
        bytes memory constructorArgs = abi.encode(
            IPoolManager(address(poolManager)),
            IAVSDirectory(address(avsDirectory)),
            IPriceOracle(address(priceOracle)),
            feeRecipient,
            lvrThreshold
        );
        
        // Test mining with all flags
        (address hookAddress, bytes32 salt) = HookMiner.mineAddress(
            deployer,
            true,  // beforeSwap
            true,  // afterSwap
            true,  // beforeAddLiquidity
            true,  // beforeRemoveLiquidity
            creationCode,
            constructorArgs
        );
        
        assertTrue(hookAddress != address(0));
        assertTrue(salt != bytes32(0));
        
        // Verify the address has the correct flags
        uint160 expectedFlags = 
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.AFTER_SWAP_FLAG |
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG;
        
        assertTrue(HookMiner.hasValidFlags(hookAddress, expectedFlags));
    }
    
    function testMineAddressWithPartialFlags() public {
        bytes memory creationCode = type(LVRAuctionHook).creationCode;
        bytes memory constructorArgs = abi.encode(
            IPoolManager(address(poolManager)),
            IAVSDirectory(address(avsDirectory)),
            IPriceOracle(address(priceOracle)),
            feeRecipient,
            lvrThreshold
        );
        
        // Test mining with only swap flags
        (address hookAddress, bytes32 salt) = HookMiner.mineAddress(
            deployer,
            true,  // beforeSwap
            true,  // afterSwap
            false, // beforeAddLiquidity
            false, // beforeRemoveLiquidity
            creationCode,
            constructorArgs
        );
        
        assertTrue(hookAddress != address(0));
        
        // Verify the address has only the correct flags
        uint160 expectedFlags = Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG;
        assertTrue(HookMiner.hasValidFlags(hookAddress, expectedFlags));
        
        // Verify it doesn't have liquidity flags
        uint160 liquidityFlags = Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG;
        assertFalse(HookMiner.hasValidFlags(hookAddress, liquidityFlags));
    }
    
    function testMineAddressWithNoFlags() public {
        bytes memory creationCode = type(LVRAuctionHook).creationCode;
        bytes memory constructorArgs = abi.encode(
            IPoolManager(address(poolManager)),
            IAVSDirectory(address(avsDirectory)),
            IPriceOracle(address(priceOracle)),
            feeRecipient,
            lvrThreshold
        );
        
        // Test mining with no flags
        (address hookAddress, bytes32 salt) = HookMiner.mineAddress(
            deployer,
            false, // beforeSwap
            false, // afterSwap
            false, // beforeAddLiquidity
            false, // beforeRemoveLiquidity
            creationCode,
            constructorArgs
        );
        
        assertTrue(hookAddress != address(0));
        assertEq(salt, bytes32(0)); // Should use salt 0 for no flags
        
        // Verify the address has no flags
        uint160 anyFlags = 0xFFFF;
        assertFalse(HookMiner.hasValidFlags(hookAddress, anyFlags));
    }
    
    function testFindWithZeroFlags() public {
        bytes memory creationCode = type(LVRAuctionHook).creationCode;
        bytes memory constructorArgs = abi.encode(
            IPoolManager(address(poolManager)),
            IAVSDirectory(address(avsDirectory)),
            IPriceOracle(address(priceOracle)),
            feeRecipient,
            lvrThreshold
        );
        
        (address hookAddress, bytes32 salt) = HookMiner.find(
            deployer,
            0, // no flags
            creationCode,
            constructorArgs
        );
        
        assertTrue(hookAddress != address(0));
        assertEq(salt, bytes32(0));
    }
    
    function testFindWithSpecificFlags() public {
        bytes memory creationCode = type(LVRAuctionHook).creationCode;
        bytes memory constructorArgs = abi.encode(
            IPoolManager(address(poolManager)),
            IAVSDirectory(address(avsDirectory)),
            IPriceOracle(address(priceOracle)),
            feeRecipient,
            lvrThreshold
        );
        
        uint160 requiredFlags = Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG;
        
        (address hookAddress, bytes32 salt) = HookMiner.find(
            deployer,
            requiredFlags,
            creationCode,
            constructorArgs
        );
        
        assertTrue(hookAddress != address(0));
        assertTrue(HookMiner.hasValidFlags(hookAddress, requiredFlags));
    }
    
    function testConsistentResults() public {
        bytes memory creationCode = type(LVRAuctionHook).creationCode;
        bytes memory constructorArgs = abi.encode(
            IPoolManager(address(poolManager)),
            IAVSDirectory(address(avsDirectory)),
            IPriceOracle(address(priceOracle)),
            feeRecipient,
            lvrThreshold
        );
        
        uint160 requiredFlags = Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG;
        
        // Mine twice with same parameters
        (address addr1, bytes32 salt1) = HookMiner.find(
            deployer,
            requiredFlags,
            creationCode,
            constructorArgs
        );
        
        (address addr2, bytes32 salt2) = HookMiner.find(
            deployer,
            requiredFlags,
            creationCode,
            constructorArgs
        );
        
        // Results should be consistent
        assertEq(addr1, addr2);
        assertEq(salt1, salt2);
    }
    
    function testDifferentDeployers() public {
        bytes memory creationCode = type(LVRAuctionHook).creationCode;
        bytes memory constructorArgs = abi.encode(
            IPoolManager(address(poolManager)),
            IAVSDirectory(address(avsDirectory)),
            IPriceOracle(address(priceOracle)),
            feeRecipient,
            lvrThreshold
        );
        
        uint160 requiredFlags = Hooks.BEFORE_SWAP_FLAG;
        
        address deployer2 = address(0x9876543210987654321098765432109876543210);
        
        (address addr1, ) = HookMiner.find(deployer, requiredFlags, creationCode, constructorArgs);
        (address addr2, ) = HookMiner.find(deployer2, requiredFlags, creationCode, constructorArgs);
        
        // Different deployers should produce different addresses
        assertTrue(addr1 != addr2);
    }
    
    function testGasUsage() public {
        bytes memory creationCode = type(LVRAuctionHook).creationCode;
        bytes memory constructorArgs = abi.encode(
            IPoolManager(address(poolManager)),
            IAVSDirectory(address(avsDirectory)),
            IPriceOracle(address(priceOracle)),
            feeRecipient,
            lvrThreshold
        );
        
        uint160 requiredFlags = Hooks.BEFORE_SWAP_FLAG;
        
        uint256 gasStart = gasleft();
        
        HookMiner.find(deployer, requiredFlags, creationCode, constructorArgs);
        
        uint256 gasUsed = gasStart - gasleft();
        
        // Should use reasonable amount of gas
        assertTrue(gasUsed < 1000000); // Less than 1M gas
        console.log("Gas used for mining:", gasUsed);
    }
}

/*//////////////////////////////////////////////////////////////
                            MOCK CONTRACTS
//////////////////////////////////////////////////////////////*/

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

contract MockPriceOracle {
    function getPrice(address, address) external pure returns (uint256) { return 1e18; }
    function getPriceAtTime(address, address, uint256) external pure returns (uint256) { return 1e18; }
    function isPriceStale(address, address) external pure returns (bool) { return false; }
    function getLastUpdateTime(address, address) external pure returns (uint256) { return block.timestamp; }
}
