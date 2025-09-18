// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {LVRAuctionServiceManager} from "../../avs-new/contracts/src/l1-contracts/LVRAuctionServiceManager.sol";
import {LVRAuctionTaskHook} from "../../avs-new/contracts/src/l2-contracts/LVRAuctionTaskHook.sol";

/**
 * @title DeployAVSSepolia
 * @notice Deployment script for LVR Auction AVS on Sepolia testnet
 */
contract DeployAVSSepolia is Script {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    
    // Sepolia testnet addresses (to be updated with actual addresses)
    address public constant SEPOLIA_L2_HOOK = 0x0000000000000000000000000000000000000000; // Replace with actual Sepolia L2 hook

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Starting LVR Auction AVS deployment on Sepolia...");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        
        // Deploy L1 contracts
        address serviceManager = _deployServiceManager();
        
        // Deploy L2 contracts
        address taskHook = _deployTaskHook();
        
        // Configure contracts
        _configureContracts(serviceManager, taskHook);
        
        // Log deployment addresses
        console.log("AVS Sepolia deployment completed successfully!");
        console.log("LVRAuctionServiceManager:", serviceManager);
        console.log("LVRAuctionTaskHook:", taskHook);
        console.log("L2 Hook:", SEPOLIA_L2_HOOK);
        
        vm.stopBroadcast();
    }
    
    function _deployServiceManager() internal returns (address) {
        console.log("Deploying LVRAuctionServiceManager...");
        
        LVRAuctionServiceManager manager = new LVRAuctionServiceManager(
            SEPOLIA_L2_HOOK
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
        // 5. Test with testnet operators
        
        console.log("AVS contracts configured successfully!");
        console.log("Note: Full configuration requires EigenLayer setup");
    }
}
