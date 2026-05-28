// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {UserLPVault} from "../src/UserLPVault.sol";
import {RangePilotTestBase} from "./utils/RangePilotTestBase.sol";

contract UserLPVaultMultiPoolTest is RangePilotTestBase {
    PoolKey internal poolBKey;
    PoolId internal poolA;
    PoolId internal poolB;

    function setUp() public {
        setUpCore();
        createFundedVault();
        poolBKey = initializeSecondPoolWithSameTokens();
        poolA = key.toId();
        poolB = poolBKey.toId();
        addPoolToVault(poolBKey);
    }

    function test_CannotUsePoolAFundsForPoolB() public {
        vm.expectRevert(UserLPVault.InsufficientIdleBalance.selector);
        vm.prank(operator);
        vault.rebalance(planFor(poolB, -60, 60, 0, 1 ether, 1));

        assertEq(activeFor(poolB).liquidity, 0);
        assertEq(balanceFor(poolA).idle0, 1_000_000 ether);
        assertEq(balanceFor(poolA).idle1, 1_000_000 ether);
    }

    function test_NonceIsScopedPerPool() public {
        fundVaultPool(poolB, 1_000_000 ether, 1_000_000 ether);

        vm.prank(operator);
        vault.rebalance(planFor(poolA, -60, 60, 0, 1 ether, 1));

        vm.prank(operator);
        vault.rebalance(planFor(poolB, -60, 60, 0, 1 ether, 1));

        assertTrue(vault.usedNonces(poolA, 1));
        assertTrue(vault.usedNonces(poolB, 1));
        assertEq(activeFor(poolA).liquidity, 1 ether);
        assertEq(activeFor(poolB).liquidity, 1 ether);
    }

    function test_WithdrawOnePoolDoesNotExitAnotherPool() public {
        fundVaultPool(poolB, 1_000_000 ether, 1_000_000 ether);
        addInitialLiquidityFor(poolA, 1);
        addInitialLiquidityFor(poolB, 1);

        vm.prank(owner);
        vault.withdraw(withdrawPlanFor(poolA));

        assertEq(activeFor(poolA).liquidity, 0);
        assertEq(activeFor(poolB).liquidity, 1 ether);
        assertGt(balanceFor(poolB).idle0 + balanceFor(poolB).idle1, 0);
    }
}
