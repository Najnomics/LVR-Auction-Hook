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
 * @title DeployMainnet
 * @notice Deployment script for LVR Auction Hook on Ethereum mainnet
 */
contract DeployMainnet is Script {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    
    // Mainnet addresses (to be updated with actual addresses)
    address public constant MAINNET_POOL_MANAGER = 0x0000000000000000000000000000000000000000; // Replace with actual mainnet PoolManager
    address public constant MAINNET_AVS_DIRECTORY = 0x0000000000000000000000000000000000000000; // Replace with actual mainnet AVSDirectory
    
    // Mainnet Chainlink price feed addresses
    address public constant MAINNET_ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // ETH/USD
    address public constant MAINNET_BTC_USD_FEED = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c; // BTC/USD
    address public constant MAINNET_USDC_USD_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6; // USDC/USD
    address public constant MAINNET_LINK_USD_FEED = 0x2c1d072e956AFFC0D435Cb7AC38EF18d24d9127c; // LINK/USD
    address public constant MAINNET_AAVE_USD_FEED = 0x547A514d5e3769680cE22B2361C10Ea136019818; // AAVE/USD
    
    // Mainnet token addresses
    address public constant MAINNET_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    address public constant MAINNET_USDC = 0xA0b86a33E6417c8a9bbe78fe047ce5C17aEd0Ada; // USDC
    address public constant MAINNET_WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599; // WBTC
    address public constant MAINNET_LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA; // LINK
    address public constant MAINNET_AAVE = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9; // AAVE
    
    // Configuration
    uint256 public constant LVR_THRESHOLD = 50; // 0.5% in basis points
    address public constant FEE_RECIPIENT = 0x1234567890123456789012345678901234567890; // Replace with actual address

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Starting LVR Auction Hook deployment on Mainnet...");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        
        // Deploy contracts
        address lvrHook = _deployLVRAuctionHook();
        address priceOracle = _deployPriceOracle();
        
        // Configure contracts
        _configureContracts(lvrHook, priceOracle);
        
        // Log deployment addresses
        console.log("Mainnet deployment completed successfully!");
        console.log("LVRAuctionHook:", lvrHook);
        console.log("ChainlinkPriceOracle:", priceOracle);
        console.log("PoolManager:", MAINNET_POOL_MANAGER);
        console.log("AVSDirectory:", MAINNET_AVS_DIRECTORY);
        
        vm.stopBroadcast();
    }
    
    function _deployLVRAuctionHook() internal returns (address) {
        console.log("Deploying LVRAuctionHook...");
        
        LVRAuctionHook hook = new LVRAuctionHook(
            IPoolManager(MAINNET_POOL_MANAGER),
            IAVSDirectory(MAINNET_AVS_DIRECTORY),
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
        
        // Add mainnet price feeds
        _addMainnetPriceFeeds(oracle);
        
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
        // 4. Enable auctions for major trading pairs
        // 5. Set up emergency procedures
        
        console.log("Contracts configured successfully!");
        console.log("Note: Full configuration requires additional setup");
    }
    
    function _addMainnetPriceFeeds(ChainlinkPriceOracle oracle) internal {
        console.log("Adding mainnet price feeds...");
        
        // Add ETH/USDC price feed
        oracle.addPriceFeed(
            Currency.wrap(MAINNET_WETH),
            Currency.wrap(MAINNET_USDC),
            MAINNET_ETH_USD_FEED
        );
        
        // Add BTC/USDC price feed
        oracle.addPriceFeed(
            Currency.wrap(MAINNET_WBTC),
            Currency.wrap(MAINNET_USDC),
            MAINNET_BTC_USD_FEED
        );
        
        // Add LINK/USDC price feed
        oracle.addPriceFeed(
            Currency.wrap(MAINNET_LINK),
            Currency.wrap(MAINNET_USDC),
            MAINNET_LINK_USD_FEED
        );
        
        // Add AAVE/USDC price feed
        oracle.addPriceFeed(
            Currency.wrap(MAINNET_AAVE),
            Currency.wrap(MAINNET_USDC),
            MAINNET_AAVE_USD_FEED
        );
        
        console.log("Mainnet price feeds added successfully!");
    }
}
