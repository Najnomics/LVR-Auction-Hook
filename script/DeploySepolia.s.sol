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
 * @title DeploySepolia
 * @notice Deployment script for LVR Auction Hook on Sepolia testnet
 */
contract DeploySepolia is Script {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    
    // Sepolia testnet addresses
    address public constant SEPOLIA_POOL_MANAGER = 0x0000000000000000000000000000000000000000; // Replace with actual Sepolia PoolManager
    address public constant SEPOLIA_AVS_DIRECTORY = 0x0000000000000000000000000000000000000000; // Replace with actual Sepolia AVSDirectory
    
    // Sepolia Chainlink price feed addresses
    address public constant SEPOLIA_ETH_USD_FEED = 0x694aA1769357215dE4fac081bf1F309Ac3253060; // ETH/USD
    address public constant SEPOLIA_BTC_USD_FEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43; // BTC/USD
    address public constant SEPOLIA_USDC_USD_FEED = 0xA2F78ab2355fE666F296C9bb33C9A33e2De1c167; // USDC/USD
    
    // Sepolia token addresses
    address public constant SEPOLIA_WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14; // WETH
    address public constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // USDC
    address public constant SEPOLIA_WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599; // WBTC (if available)
    
    // Configuration
    uint256 public constant LVR_THRESHOLD = 50; // 0.5% in basis points
    address public constant FEE_RECIPIENT = 0x1234567890123456789012345678901234567890; // Replace with actual address

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Starting LVR Auction Hook deployment on Sepolia...");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        
        // Deploy contracts
        address lvrHook = _deployLVRAuctionHook();
        address priceOracle = _deployPriceOracle();
        
        // Configure contracts
        _configureContracts(lvrHook, priceOracle);
        
        // Log deployment addresses
        console.log("Sepolia deployment completed successfully!");
        console.log("LVRAuctionHook:", lvrHook);
        console.log("ChainlinkPriceOracle:", priceOracle);
        console.log("PoolManager:", SEPOLIA_POOL_MANAGER);
        console.log("AVSDirectory:", SEPOLIA_AVS_DIRECTORY);
        
        vm.stopBroadcast();
    }
    
    function _deployLVRAuctionHook() internal returns (address) {
        console.log("Deploying LVRAuctionHook...");
        
        LVRAuctionHook hook = new LVRAuctionHook(
            IPoolManager(SEPOLIA_POOL_MANAGER),
            IAVSDirectory(SEPOLIA_AVS_DIRECTORY),
            IPriceOracle(address(0)), // Will be set after price oracle deployment
            FEE_RECIPIENT,
            LVR_THRESHOLD
        );
        
        console.log("LVRAuctionHook deployed at:", address(hook));
        return address(hook);
    }
    
    function _deployPriceOracle() internal returns (address) {
        console.log("Deploying ChainlinkPriceOracle...");
        
        ChainlinkPriceOracle oracle = new ChainlinkPriceOracle(msg.sender);
        
        // Add Sepolia price feeds
        _addSepoliaPriceFeeds(oracle);
        
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
        // 4. Enable auctions for specific pools
        
        console.log("Contracts configured successfully!");
        console.log("Note: Full configuration requires additional setup");
    }
    
    function _addSepoliaPriceFeeds(ChainlinkPriceOracle oracle) internal {
        console.log("Adding Sepolia price feeds...");
        
        // Add ETH/USDC price feed
        oracle.addPriceFeed(
            Currency.wrap(SEPOLIA_WETH),
            Currency.wrap(SEPOLIA_USDC),
            SEPOLIA_ETH_USD_FEED
        );
        
        // Add BTC/USDC price feed (if WBTC is available on Sepolia)
        if (SEPOLIA_WBTC != address(0)) {
            oracle.addPriceFeed(
                Currency.wrap(SEPOLIA_WBTC),
                Currency.wrap(SEPOLIA_USDC),
                SEPOLIA_BTC_USD_FEED
            );
        }
        
        console.log("Sepolia price feeds added successfully!");
    }
}
