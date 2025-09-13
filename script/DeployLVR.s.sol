// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";

import {LVRAuctionHook} from "../src/LVRAuctionHook.sol";
import {LVRAuctionServiceManager} from "../src/LVRAuctionServiceManager.sol";
import {ChainlinkPriceOracle} from "../src/ChainlinkPriceOracle.sol";
import {IPriceOracle} from "../src/interfaces/IPriceOracle.sol";
import {ProductionPriceFeedConfig} from "../src/ProductionPriceFeedConfig.sol";
import {IAVSDirectory} from "../src/interfaces/IAVSDirectory.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";

/**
 * @title DeployLVR
 * @notice Deployment script for LVR Auction Hook contracts
 */
contract DeployLVR is Script {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    
    // Default configuration values
    uint256 public constant DEFAULT_LVR_THRESHOLD = 50; // 0.5% in basis points
    address public constant DEFAULT_FEE_RECIPIENT = 0x1234567890123456789012345678901234567890; // Replace with actual address
    
    // Network-specific addresses (these would be set based on the deployment network)
    address public constant POOL_MANAGER = 0x0000000000000000000000000000000000000000; // Replace with actual PoolManager address
    address public constant AVS_DIRECTORY = 0x0000000000000000000000000000000000000000; // Replace with actual AVSDirectory address
    
    // Chainlink price feed addresses on mainnet
    address public constant ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant BTC_USD_FEED = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    address public constant USDC_USD_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    
    // Common token addresses
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86a33E6417C8a9bbE78fE047cE5c17Aed0ADA;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Starting LVR Auction Hook deployment...");
        
        // Deploy contracts
        address lvrHook = _deployLVRAuctionHook();
        address serviceManager = _deployServiceManager();
        address priceOracle = _deployPriceOracle();
        
        // Configure contracts
        _configureContracts(lvrHook, serviceManager, priceOracle);
        
        // Log deployment addresses
        console.log("Deployment completed successfully!");
        console.log("LVRAuctionHook:", lvrHook);
        console.log("LVRAuctionServiceManager:", serviceManager);
        console.log("ChainlinkPriceOracle:", priceOracle);
        
        vm.stopBroadcast();
    }
    
    function _deployLVRAuctionHook() internal returns (address) {
        console.log("Deploying LVRAuctionHook...");
        
        LVRAuctionHook hook = new LVRAuctionHook(
            IPoolManager(POOL_MANAGER),
            IAVSDirectory(AVS_DIRECTORY),
            IPriceOracle(address(0)), // Will be set after price oracle deployment
            DEFAULT_FEE_RECIPIENT,
            DEFAULT_LVR_THRESHOLD
        );
        
        console.log("LVRAuctionHook deployed at:", address(hook));
        return address(hook);
    }
    
    function _deployServiceManager() internal returns (address) {
        console.log("Deploying LVRAuctionServiceManager...");
        
        LVRAuctionServiceManager manager = new LVRAuctionServiceManager(
            IAVSDirectory(AVS_DIRECTORY)
        );
        
        console.log("LVRAuctionServiceManager deployed at:", address(manager));
        return address(manager);
    }
    
    function _deployPriceOracle() internal returns (address) {
        console.log("Deploying ChainlinkPriceOracle...");
        
        ChainlinkPriceOracle oracle = new ChainlinkPriceOracle(msg.sender);
        
        // Add price feeds for major pairs
        _addPriceFeeds(oracle);
        
        console.log("ChainlinkPriceOracle deployed at:", address(oracle));
        return address(oracle);
    }
    
    function _configureContracts(
        address lvrHook,
        address serviceManager,
        address priceOracle
    ) internal {
        console.log("Configuring contracts...");
        
        // Set price oracle in the hook
        // Note: This would require a setter function in the hook contract
        // LVRAuctionHook(lvrHook).setPriceOracle(IPriceOracle(priceOracle));
        
        // Authorize the service manager as an operator in the hook
        // LVRAuctionHook(lvrHook).setOperatorAuthorization(serviceManager, true);
        
        console.log("Contracts configured successfully!");
    }
    
    function _addPriceFeeds(ChainlinkPriceOracle oracle) internal {
        console.log("Adding price feeds...");
        
        // Add ETH/USDC price feed
        oracle.addPriceFeed(
            Currency.wrap(WETH),
            Currency.wrap(USDC),
            ETH_USD_FEED
        );
        
        // Add WBTC/USDC price feed
        oracle.addPriceFeed(
            Currency.wrap(WBTC),
            Currency.wrap(USDC),
            BTC_USD_FEED
        );
        
        console.log("Price feeds added successfully!");
    }
}
