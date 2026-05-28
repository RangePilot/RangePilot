// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {RebalancePlan} from "../src/libraries/RangePilotTypes.sol";
import {UserLPVault} from "../src/UserLPVault.sol";
import {RangePilotTestBase} from "./utils/RangePilotTestBase.sol";

contract UserLPVaultStrategyTest is RangePilotTestBase {
    function setUp() public {
        setUpCore();
        createFundedVault();
    }

    function test_ExpiredPlanReverts() public {
        RebalancePlan memory expired = plan(-60, 60, 0, 1 ether, 1);
        expired.deadline = block.timestamp - 1;

        vm.expectRevert(UserLPVault.DeadlineExpired.selector);
        vm.prank(operator);
        vault.rebalance(expired);
    }

    function test_ReusedNonceReverts() public {
        addInitialLiquidity();

        RebalancePlan memory reused = plan(-120, 120, active().liquidity, 1 ether, 1);
        vm.expectRevert(UserLPVault.NonceAlreadyUsed.selector);
        vm.prank(operator);
        vault.rebalance(reused);
    }

    function test_RangeTooNarrowReverts() public {
        vm.expectRevert(UserLPVault.InvalidTickRange.selector);
        vm.prank(operator);
        vault.rebalance(plan(0, 30, 0, 1 ether, 1));
    }

    function test_RangeTooWideReverts() public {
        vm.expectRevert(UserLPVault.InvalidTickRange.selector);
        vm.prank(operator);
        vault.rebalance(plan(-600, 600, 0, 1 ether, 1));
    }

    function test_TickMoveTooLargeReverts() public {
        addInitialLiquidity();
        uint128 liquidity = active().liquidity;

        vm.expectRevert(UserLPVault.TickMoveTooLarge.selector);
        vm.prank(operator);
        vault.rebalance(plan(-240, 240, liquidity, 1 ether, 2));
    }

    function test_ValidRebalanceUpdatesActivePosition() public {
        addInitialLiquidity();
        uint128 liquidity = active().liquidity;

        vm.prank(operator);
        vault.rebalance(plan(-120, 120, liquidity, 2 ether, 2));

        assertEq(active().tickLower, -120);
        assertEq(active().tickUpper, 120);
        assertEq(active().liquidity, 2 ether);
    }
}
