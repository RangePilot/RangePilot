// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {StrategyConfig} from "../src/libraries/RangePilotTypes.sol";
import {UserLPVault} from "../src/UserLPVault.sol";
import {RangePilotTestBase} from "./utils/RangePilotTestBase.sol";

contract UserLPVaultPermissionsTest is RangePilotTestBase {
    function setUp() public {
        setUpCore();
        createFundedVault();
    }

    function test_OwnerCanDeposit() public {
        token0.mint(owner, 1 ether);
        token1.mint(owner, 1 ether);

        vm.startPrank(owner);
        token0.approve(address(vault), 1 ether);
        token1.approve(address(vault), 1 ether);
        vault.deposit(key.toId(), 1 ether, 1 ether);
        vm.stopPrank();

        assertEq(token0.balanceOf(address(vault)), 1_000_001 ether);
        assertEq(token1.balanceOf(address(vault)), 1_000_001 ether);
    }

    function test_AIOperatorCanRebalance() public {
        addInitialLiquidity();
        assertEq(active().liquidity, 1 ether);
    }

    function test_NonOperatorCannotRebalance() public {
        vm.expectRevert(UserLPVault.NotOperator.selector);
        vm.prank(other);
        vault.rebalance(plan(-60, 60, 0, 1 ether, 1));
    }

    function test_AIOperatorCannotWithdraw() public {
        addInitialLiquidity();

        vm.expectRevert(UserLPVault.NotOwner.selector);
        vm.prank(operator);
        vault.withdraw(withdrawPlan());
    }

    function test_OwnerCanWithdraw() public {
        addInitialLiquidity();

        vm.prank(owner);
        vault.withdraw(withdrawPlan());

        assertEq(active().liquidity, 0);
        assertGt(token0.balanceOf(owner) + token1.balanceOf(owner), 0);
    }

    function test_OwnerCanUpdateStrategyConfig() public {
        StrategyConfig memory config = defaultConfig();
        config.maxWidth = 1200;

        vm.prank(owner);
        vault.updateStrategyConfig(key.toId(), config);

        assertEq(vault.getStrategyConfig(key.toId()).maxWidth, 1200);
    }

    function test_AIOperatorCannotUpdateStrategyConfig() public {
        vm.expectRevert(UserLPVault.NotOwner.selector);
        vm.prank(operator);
        vault.updateStrategyConfig(key.toId(), defaultConfig());
    }

    function test_OwnerCanRevokeAIOperator() public {
        vm.prank(owner);
        vault.revokeAIOperator();

        vm.expectRevert(UserLPVault.NotOperator.selector);
        vm.prank(operator);
        vault.rebalance(plan(-60, 60, 0, 1 ether, 1));
    }
}
