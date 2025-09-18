// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {LVRAuctionServiceManager} from "../../avs-new/contracts/src/l1-contracts/LVRAuctionServiceManager.sol";
import {LVRAuctionTaskHook} from "../../avs-new/contracts/src/l2-contracts/LVRAuctionTaskHook.sol";

/**
 * @title DeployAVSAnvil
 * @notice Deployment script for LVR Auction AVS on Anvil (local development)
 */
contract DeployAVSAnvil is Script {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    
    // Anvil configuration
    uint256 public constant ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address public constant ANVIL_DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    
    // Mock addresses for Anvil
    address public constant MOCK_L2_HOOK = 0x1234567890123456789012345678901234567890;

    function run() external {
        // Use Anvil's default private key
        vm.startBroadcast(ANVIL_PRIVATE_KEY);
        
        console.log("Starting LVR Auction AVS deployment on Anvil...");
        console.log("Deployer:", ANVIL_DEPLOYER);
        
        // Deploy L1 contracts
        address serviceManager = _deployServiceManager();
        
        // Deploy L2 contracts
        address taskHook = _deployTaskHook();
        
        // Configure contracts
        _configureContracts(serviceManager, taskHook);
        
        // Log deployment addresses
        console.log("AVS Anvil deployment completed successfully!");
        console.log("LVRAuctionServiceManager:", serviceManager);
        console.log("LVRAuctionTaskHook:", taskHook);
        console.log("Mock L2 Hook:", MOCK_L2_HOOK);
        
        vm.stopBroadcast();
    }
    
    function _deployServiceManager() internal returns (address) {
        console.log("Deploying LVRAuctionServiceManager...");
        
        LVRAuctionServiceManager manager = new LVRAuctionServiceManager(
            MOCK_L2_HOOK
        );
        
        console.log("LVRAuctionServiceManager deployed at:", address(manager));
        return address(manager);
    }
    
    function _deployTaskHook() internal returns (address) {
        console.log("Deploying LVRAuctionTaskHook...");
        
        LVRAuctionTaskHook hook = new LVRAuctionTaskHook();
        
        console.log("LVRAuctionTaskHook deployed at:", address(hook));
        return address(hook);
    }
    
    function _configureContracts(
        address serviceManager,
        address taskHook
    ) internal {
        console.log("Configuring AVS contracts...");
        
        // Note: In a real deployment, you would:
        // 1. Register the AVS with EigenLayer
        // 2. Set up operator permissions
        // 3. Configure task parameters
        // 4. Set up monitoring and alerting
        
        console.log("AVS contracts configured successfully!");
        console.log("Note: Full configuration requires EigenLayer setup");
    }
}
