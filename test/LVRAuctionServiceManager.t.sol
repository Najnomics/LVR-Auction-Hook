// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";

import {LVRAuctionServiceManager} from "../src/LVRAuctionServiceManager.sol";
import {IAVSDirectory} from "../src/interfaces/IAVSDirectory.sol";

/**
 * @title LVRAuctionServiceManagerTest
 * @notice Comprehensive test suite for LVR Auction Service Manager
 */
contract LVRAuctionServiceManagerTest is Test {
    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/
    
    LVRAuctionServiceManager public serviceManager;
    MockAVSDirectory public mockAVSDirectory;
    
    address public owner;
    address public operator1;
    address public operator2;
    address public operator3;
    
    uint256 public constant MINIMUM_STAKE = 32 ether;
    uint256 public constant MINIMUM_QUORUM_SIZE = 3;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/
    
    function setUp() public {
        owner = address(this);
        operator1 = address(0x1);
        operator2 = address(0x2);
        operator3 = address(0x3);
        
        // Deploy mock AVS Directory
        mockAVSDirectory = new MockAVSDirectory();
        
        // Deploy service manager
        serviceManager = new LVRAuctionServiceManager(IAVSDirectory(address(mockAVSDirectory)));
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testConstructor() public {
        assertEq(address(serviceManager.avsDirectory()), address(mockAVSDirectory));
        assertEq(serviceManager.owner(), owner);
        assertEq(serviceManager.latestTaskNum(), 0);
        assertEq(serviceManager.getOperatorCount(), 0);
    }
    
    function testConstants() public {
        assertEq(serviceManager.MINIMUM_STAKE(), MINIMUM_STAKE);
        assertEq(serviceManager.TASK_RESPONSE_WINDOW(), 60);
        assertEq(serviceManager.CHALLENGE_WINDOW(), 7 days);
        assertEq(serviceManager.MINIMUM_QUORUM_SIZE(), MINIMUM_QUORUM_SIZE);
    }
    
    function testRegisterOperator() public {
        vm.deal(operator1, MINIMUM_STAKE);
        
        vm.prank(operator1);
        serviceManager.registerOperator{value: MINIMUM_STAKE}(bytes("signature"));
        
        assertTrue(serviceManager.operatorRegistered(operator1));
        assertEq(serviceManager.operatorStakes(operator1), MINIMUM_STAKE);
        assertEq(serviceManager.getOperatorCount(), 1);
        assertEq(serviceManager.registeredOperators(0), operator1);
    }
    
    function testRegisterOperatorInsufficientStake() public {
        vm.deal(operator1, MINIMUM_STAKE - 1);
        
        vm.prank(operator1);
        vm.expectRevert("Insufficient stake");
        serviceManager.registerOperator{value: MINIMUM_STAKE - 1}(bytes("signature"));
    }
    
    function testRegisterOperatorAlreadyRegistered() public {
        vm.deal(operator1, MINIMUM_STAKE);
        
        vm.prank(operator1);
        serviceManager.registerOperator{value: MINIMUM_STAKE}(bytes("signature"));
        
        vm.prank(operator1);
        vm.expectRevert("Already registered");
        serviceManager.registerOperator{value: MINIMUM_STAKE}(bytes("signature"));
    }
    
    function testDeregisterOperator() public {
        vm.deal(operator1, MINIMUM_STAKE);
        
        // Register operator
        vm.prank(operator1);
        serviceManager.registerOperator{value: MINIMUM_STAKE}(bytes("signature"));
        
        uint256 initialBalance = operator1.balance;
        
        // Deregister operator
        vm.prank(operator1);
        serviceManager.deregisterOperator();
        
        assertFalse(serviceManager.operatorRegistered(operator1));
        assertEq(serviceManager.operatorStakes(operator1), 0);
        assertEq(serviceManager.getOperatorCount(), 0);
        assertEq(operator1.balance, initialBalance + MINIMUM_STAKE);
    }
    
    function testAddStake() public {
        vm.deal(operator1, MINIMUM_STAKE * 2);
        
        // Register operator
        vm.prank(operator1);
        serviceManager.registerOperator{value: MINIMUM_STAKE}(bytes("signature"));
        
        // Add additional stake
        uint256 additionalStake = 10 ether;
        vm.prank(operator1);
        serviceManager.addStake{value: additionalStake}();
        
        assertEq(serviceManager.operatorStakes(operator1), MINIMUM_STAKE + additionalStake);
    }
    
    function testCreateAuctionTask() public {
        // Register operators first
        _registerOperators();
        
        bytes32 auctionId = keccak256(abi.encodePacked("auction1"));
        bytes32 poolId = keccak256(abi.encodePacked("pool1"));
        
        uint32 taskIndex = serviceManager.createAuctionTask(auctionId, poolId);
        
        assertEq(taskIndex, 0);
        assertEq(serviceManager.latestTaskNum(), 1);
        
        (bytes32 taskAuctionId, bytes32 taskPoolId, uint32 createdBlock, uint256 deadline, bool completed) = 
            serviceManager.getTask(taskIndex);
        
        assertEq(taskAuctionId, auctionId);
        assertEq(taskPoolId, poolId);
        assertEq(createdBlock, block.number);
        assertEq(completed, false);
        assertEq(deadline, block.timestamp + 60);
    }
    
    function testCreateAuctionTaskInsufficientOperators() public {
        bytes32 auctionId = keccak256(abi.encodePacked("auction1"));
        bytes32 poolId = keccak256(abi.encodePacked("pool1"));
        
        vm.expectRevert("Insufficient operators");
        serviceManager.createAuctionTask(auctionId, poolId);
    }
    
    function testRespondToTask() public {
        // Setup
        _registerOperators();
        bytes32 auctionId = keccak256(abi.encodePacked("auction1"));
        bytes32 poolId = keccak256(abi.encodePacked("pool1"));
        uint32 taskIndex = serviceManager.createAuctionTask(auctionId, poolId);
        
        // Respond to task
        address winner = address(0x5);
        uint256 winningBid = 1 ether;
        bytes memory signature = bytes("signature");
        
        vm.prank(operator1);
        serviceManager.respondToTask(taskIndex, winner, winningBid, signature);
        
        assertTrue(serviceManager.operatorResponded(taskIndex, operator1));
        
        (address taskOperator, bytes32 taskAuctionId, address taskWinner, uint256 taskWinningBid, , uint256 timestamp) = 
            serviceManager.getTaskResponse(taskIndex, operator1);
        
        assertEq(taskOperator, operator1);
        assertEq(taskAuctionId, auctionId);
        assertEq(taskWinner, winner);
        assertEq(taskWinningBid, winningBid);
        assertEq(timestamp, block.timestamp);
    }
    
    function testRespondToTaskNotRegistered() public {
        bytes32 auctionId = keccak256(abi.encodePacked("auction1"));
        bytes32 poolId = keccak256(abi.encodePacked("pool1"));
        uint32 taskIndex = serviceManager.createAuctionTask(auctionId, poolId);
        
        vm.prank(operator1);
        vm.expectRevert("Not a registered operator");
        serviceManager.respondToTask(taskIndex, address(0x5), 1 ether, bytes("signature"));
    }
    
    function testRespondToTaskAlreadyResponded() public {
        _registerOperators();
        bytes32 auctionId = keccak256(abi.encodePacked("auction1"));
        bytes32 poolId = keccak256(abi.encodePacked("pool1"));
        uint32 taskIndex = serviceManager.createAuctionTask(auctionId, poolId);
        
        vm.prank(operator1);
        serviceManager.respondToTask(taskIndex, address(0x5), 1 ether, bytes("signature"));
        
        vm.prank(operator1);
        vm.expectRevert("Already responded");
        serviceManager.respondToTask(taskIndex, address(0x6), 2 ether, bytes("signature"));
    }
    
    function testChallengeTask() public {
        _registerOperators();
        bytes32 auctionId = keccak256(abi.encodePacked("auction1"));
        bytes32 poolId = keccak256(abi.encodePacked("pool1"));
        uint32 taskIndex = serviceManager.createAuctionTask(auctionId, poolId);
        
        // Complete task first (simplified)
        vm.prank(operator1);
        serviceManager.respondToTask(taskIndex, address(0x5), 1 ether, bytes("signature"));
        
        // Challenge task
        vm.deal(address(0x7), 0.1 ether);
        vm.prank(address(0x7));
        serviceManager.challengeTask{value: 0.1 ether}(taskIndex);
        
        assertTrue(serviceManager.taskChallenged(taskIndex));
    }
    
    function testSlashOperator() public {
        vm.deal(operator1, MINIMUM_STAKE);
        
        vm.prank(operator1);
        serviceManager.registerOperator{value: MINIMUM_STAKE}(bytes("signature"));
        
        uint256 slashAmount = 5 ether;
        serviceManager.slashOperator(operator1, slashAmount);
        
        assertEq(serviceManager.operatorStakes(operator1), MINIMUM_STAKE - slashAmount);
        assertEq(serviceManager.rewardPool(), slashAmount);
    }
    
    function testHasQuorum() public {
        assertFalse(serviceManager.hasQuorum());
        
        _registerOperators();
        assertTrue(serviceManager.hasQuorum());
    }
    
    function testWithdraw() public {
        vm.deal(address(serviceManager), 10 ether);
        
        uint256 initialBalance = owner.balance;
        serviceManager.withdraw();
        
        assertEq(owner.balance, initialBalance + 10 ether);
    }
    
    function testFundRewardPool() public {
        vm.deal(address(this), 5 ether);
        serviceManager.fundRewardPool{value: 5 ether}();
        
        assertEq(serviceManager.rewardPool(), 5 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    function _registerOperators() internal {
        vm.deal(operator1, MINIMUM_STAKE);
        vm.deal(operator2, MINIMUM_STAKE);
        vm.deal(operator3, MINIMUM_STAKE);
        
        vm.prank(operator1);
        serviceManager.registerOperator{value: MINIMUM_STAKE}(bytes("signature1"));
        
        vm.prank(operator2);
        serviceManager.registerOperator{value: MINIMUM_STAKE}(bytes("signature2"));
        
        vm.prank(operator3);
        serviceManager.registerOperator{value: MINIMUM_STAKE}(bytes("signature3"));
    }
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
