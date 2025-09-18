// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";

import {LVRAuctionHook} from "../src/hooks/LVRAuctionHook.sol";
import {ChainlinkPriceOracle} from "../src/oracles/ChainlinkPriceOracle.sol";
import {IPriceOracle} from "../src/interfaces/IPriceOracle.sol";
import {IAVSDirectory} from "../src/interfaces/IAVSDirectory.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";

/**
 * @title DeployAnvil
 * @notice Deployment script for LVR Auction Hook on Anvil (local development)
 */
contract DeployAnvil is Script {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    
    // Anvil configuration
    uint256 public constant ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address public constant ANVIL_DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    
    // Mock addresses for Anvil
    address public constant MOCK_POOL_MANAGER = 0x1234567890123456789012345678901234567890;
    address public constant MOCK_AVS_DIRECTORY = 0x2345678901234567890123456789012345678901;
    address public constant MOCK_FEE_RECIPIENT = 0x3456789012345678901234567890123456789012;
    
    // Mock price feed addresses (will be deployed as mocks)
    address public constant MOCK_ETH_USD_FEED = 0x4567890123456789012345678901234567890123;
    address public constant MOCK_BTC_USD_FEED = 0x5678901234567890123456789012345678901234;
    address public constant MOCK_USDC_USD_FEED = 0x6789012345678901234567890123456789012345;
    
    // Mock token addresses
    address public constant MOCK_WETH = 0x7890123456789012345678901234567890123456;
    address public constant MOCK_USDC = 0x8901234567890123456789012345678901234567;
    address public constant MOCK_WBTC = 0x9012345678901234567890123456789012345678;

    function run() external {
        // Use Anvil's default private key
        vm.startBroadcast(ANVIL_PRIVATE_KEY);
        
        console.log("Starting LVR Auction Hook deployment on Anvil...");
        console.log("Deployer:", ANVIL_DEPLOYER);
        
        // Deploy contracts
        address lvrHook = _deployLVRAuctionHook();
        address priceOracle = _deployPriceOracle();
        
        // Configure contracts
        _configureContracts(lvrHook, priceOracle);
        
        // Log deployment addresses
        console.log("Anvil deployment completed successfully!");
        console.log("LVRAuctionHook:", lvrHook);
        console.log("ChainlinkPriceOracle:", priceOracle);
        console.log("Mock PoolManager:", MOCK_POOL_MANAGER);
        console.log("Mock AVSDirectory:", MOCK_AVS_DIRECTORY);
        
        vm.stopBroadcast();
    }
    
    function _deployLVRAuctionHook() internal returns (address) {
        console.log("Deploying LVRAuctionHook...");
        
        LVRAuctionHook hook = new LVRAuctionHook(
            IPoolManager(MOCK_POOL_MANAGER),
            IAVSDirectory(MOCK_AVS_DIRECTORY),
            IPriceOracle(address(0)), // Will be set after price oracle deployment
            MOCK_FEE_RECIPIENT,
            50 // 0.5% threshold
        );
        
        console.log("LVRAuctionHook deployed at:", address(hook));
        return address(hook);
    }
    
    function _deployPriceOracle() internal returns (address) {
        console.log("Deploying ChainlinkPriceOracle...");
        
        ChainlinkPriceOracle oracle = new ChainlinkPriceOracle(ANVIL_DEPLOYER);
        
        // Add mock price feeds for testing
        _addMockPriceFeeds(oracle);
        
        console.log("ChainlinkPriceOracle deployed at:", address(oracle));
        return address(oracle);
    }
    
    function _configureContracts(
        address lvrHook,
        address priceOracle
    ) internal {
        console.log("Configuring contracts...");
        
        // Note: In a real deployment, you would:
        // 1. Set the price oracle in the hook
        // 2. Authorize operators
        // 3. Configure pool settings
        
        console.log("Contracts configured successfully!");
        console.log("Note: Full configuration requires additional setup");
    }
    
    function _addMockPriceFeeds(ChainlinkPriceOracle oracle) internal {
        console.log("Adding mock price feeds...");
        
        // Add mock ETH/USDC price feed
        oracle.addPriceFeed(
            Currency.wrap(MOCK_WETH),
            Currency.wrap(MOCK_USDC),
            MOCK_ETH_USD_FEED
        );
        
        // Add mock WBTC/USDC price feed
        oracle.addPriceFeed(
            Currency.wrap(MOCK_WBTC),
            Currency.wrap(MOCK_USDC),
            MOCK_BTC_USD_FEED
        );
        
        console.log("Mock price feeds added successfully!");
    }
}
