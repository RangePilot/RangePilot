// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {UserLPVault} from "../src/UserLPVault.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {RangePilotTestBase} from "./utils/RangePilotTestBase.sol";

contract VaultFactoryTest is RangePilotTestBase {
    function setUp() public {
        setUpCore();
    }

    function test_CreateVaultCloneInitializesAndRegisters() public {
        vm.prank(owner);
        (address vaultAddress,) = factory.createVaultAndAddPool(owner, operator, key, defaultConfig());
        UserLPVault created = UserLPVault(vaultAddress);

        assertEq(created.owner(), owner);
        assertEq(created.aiOperator(), operator);
        assertEq(address(created.poolManager()), address(manager));
        assertEq(address(created.hook()), address(hook));
        assertEq(factory.userVaults(owner), vaultAddress);
        assertTrue(factory.isVault(vaultAddress));
        assertTrue(created.isPoolEnabled(key.toId()));
        assertTrue(hook.registeredVaultForPool(key.toId(), vaultAddress));
    }

    function test_CannotCreateSecondVaultForSameOwner() public {
        vm.startPrank(owner);
        factory.createVault(owner, operator);
        vm.expectRevert();
        factory.createVault(owner, operator);
        vm.stopPrank();
    }

    function test_OwnerCanAddSecondPoolToExistingVault() public {
        createVaultOnly();
        addPoolToVault(key);
        PoolKey memory poolKey = initializeSecondPoolWithSameTokens();

        vm.prank(owner);
        factory.addPoolToVault(poolKey, defaultConfig());

        assertTrue(vault.isPoolEnabled(key.toId()));
        assertTrue(vault.isPoolEnabled(poolKey.toId()));
        assertTrue(hook.registeredVaultForPool(key.toId(), address(vault)));
        assertTrue(hook.registeredVaultForPool(poolKey.toId(), address(vault)));
        assertEq(vault.poolCount(), 2);
    }

    function test_CannotAddPoolWithoutVault() public {
        vm.expectRevert(abi.encodeWithSelector(VaultFactory.VaultNotFound.selector, owner));
        vm.prank(owner);
        factory.addPoolToVault(key, defaultConfig());
    }

    function test_CannotCreateVaultForAnotherOwner() public {
        vm.expectRevert(VaultFactory.NotOwner.selector);
        factory.createVault(owner, operator);
    }
}
