// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {RangePilotTestBase} from "./utils/RangePilotTestBase.sol";

contract RangePilotIntegrationTest is RangePilotTestBase {
    function setUp() public {
        setUpCore();
        createFundedVault();
    }

    function test_DepositRebalanceCollectWithdrawFlow() public {
        addInitialLiquidity();

        vm.prank(operator);
        vault.collectFees(key.toId());

        vm.warp(block.timestamp + 1 hours);
        uint128 liquidity = active().liquidity;
        vm.prank(operator);
        vault.rebalance(plan(-120, 120, liquidity, 2 ether, 2));

        vm.prank(owner);
        vault.withdraw(withdrawPlan());

        assertEq(active().liquidity, 0);
        assertEq(token0.balanceOf(address(vault)), 0);
        assertEq(token1.balanceOf(address(vault)), 0);
        assertGt(token0.balanceOf(owner), 0);
        assertGt(token1.balanceOf(owner), 0);
    }
}
