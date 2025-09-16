// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {AuctionLib} from "../../src/libraries/AuctionLib.sol";
import {PoolId} from "@uniswap/v4-core/types/PoolId.sol";

/**
 * @title AuctionFuzzTest
 * @notice Fuzz testing for auction logic with random inputs
 */
contract AuctionFuzzTest is Test {
    using AuctionLib for AuctionLib.Auction;
    
    AuctionLib.Auction internal testAuction;
    
    function setUp() public {
        testAuction = AuctionLib.Auction({
            poolId: PoolId.wrap(bytes32(uint256(1))),
            startTime: block.timestamp,
            duration: 3600,
            isActive: true,
            isComplete: false,
            winner: address(0),
            winningBid: 0,
            totalBids: 0
        });
    }
    
    function testFuzz_AuctionTiming(uint256 startTime, uint256 duration) public {
        // Bound inputs to reasonable ranges
        vm.assume(startTime <= block.timestamp + 365 days);
        vm.assume(duration <= 365 days);
        vm.assume(duration > 0);
        
        testAuction.startTime = startTime;
        testAuction.duration = duration;
        
        // Test that auction timing logic is consistent
        bool isActive = testAuction.isAuctionActive();
        bool isEnded = testAuction.isAuctionEnded();
        
        // An auction cannot be both active and ended
        assertFalse(isActive && isEnded);
        
        // If current time is before start, auction should not be active
        if (block.timestamp < startTime) {
            assertFalse(isActive);
        }
        
        // If current time is after end, auction should not be active
        if (block.timestamp >= startTime + duration) {
            assertFalse(isActive);
        }
    }
    
    function testFuzz_TimeRemaining(uint256 startTime, uint256 duration) public {
        vm.assume(startTime <= block.timestamp + 365 days);
        vm.assume(duration <= 365 days);
        vm.assume(duration > 0);
        
        testAuction.startTime = startTime;
        testAuction.duration = duration;
        
        uint256 timeRemaining = testAuction.getTimeRemaining();
        
        // Time remaining should never exceed duration
        assertLe(timeRemaining, duration);
        
        // If auction hasn't started, time remaining should equal duration
        if (block.timestamp < startTime) {
            assertEq(timeRemaining, duration);
        }
        
        // If auction has ended, time remaining should be 0
        if (block.timestamp >= startTime + duration) {
            assertEq(timeRemaining, 0);
        }
    }
    
    function testFuzz_AuctionState(uint256 bidAmount, bool isActive, bool isComplete) public {
        vm.assume(bidAmount <= 1000 ether);
        
        testAuction.isActive = isActive;
        testAuction.isComplete = isComplete;
        testAuction.winningBid = bidAmount;
        
        // Test auction state consistency
        if (isComplete) {
            assertFalse(isActive, "Completed auction should not be active");
        }
        
        if (bidAmount > 0) {
            assertTrue(testAuction.winner != address(0), "Non-zero bid should have winner");
        }
    }
}
