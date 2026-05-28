// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {RangePilotTestBase} from "./utils/RangePilotTestBase.sol";
import {ManagedLPHook} from "../src/ManagedLPHook.sol";
import {UserLPVault} from "../src/UserLPVault.sol";
import {TestLiquidityRouter} from "./utils/TestLiquidityRouter.sol";

contract ManagedLPHookTest is RangePilotTestBase {
    function setUp() public {
        setUpCore();
    }

    function test_UnregisteredAddressCannotAddLiquidity() public {
        TestLiquidityRouter router = unregisteredRouter();
        vm.expectRevert();
        router.modifyLiquidity(key, addParams(-60, 60, 1 ether), "");
    }

    function test_RegisteredVaultCanAddLiquidity() public {
        createFundedVault();

        vm.prank(operator);
        vault.rebalance(plan(-60, 60, 0, 1 ether, 1));

        assertEq(active().liquidity, 1 ether);
        assertTrue(hook.registeredVaultForPool(key.toId(), address(vault)));
    }

    function test_NonFactoryCannotRegisterVault() public {
        vm.expectRevert(ManagedLPHook.NotFactory.selector);
        hook.registerVault(address(0x1234), key);
    }

    function test_RegisteredVaultCanUseMultiplePools() public {
        createFundedVault();
        PoolKey memory poolKey = initializeSecondPoolWithSameTokens();
        addPoolToVault(poolKey);
        fundVaultPool(poolKey.toId(), 1_000_000 ether, 1_000_000 ether);

        vm.prank(operator);
        vault.rebalance(planFor(poolKey.toId(), -60, 60, 0, 1 ether, 2));

        assertEq(activeFor(poolKey.toId()).liquidity, 1 ether);
        assertTrue(hook.registeredVaultForPool(key.toId(), address(vault)));
        assertTrue(hook.registeredVaultForPool(poolKey.toId(), address(vault)));
    }

    function test_BadTickRangeReverts() public {
        createFundedVault();
        vm.expectRevert(UserLPVault.InvalidTickRange.selector);
        vm.prank(operator);
        vault.rebalance(plan(60, -60, 0, 1 ether, 1));
    }
}
