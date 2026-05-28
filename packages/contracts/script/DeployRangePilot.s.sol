// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {HookCreate2Deployer} from "../src/deploy/HookCreate2Deployer.sol";
import {ManagedLPHook} from "../src/ManagedLPHook.sol";
import {UserLPVault} from "../src/UserLPVault.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {HookMiner} from "./HookMiner.sol";

contract DeployRangePilot is Script {
    function run()
        external
        returns (HookCreate2Deployer hookDeployer, ManagedLPHook hook, UserLPVault implementation, VaultFactory factory)
    {
        IPoolManager poolManager = IPoolManager(vm.envAddress("POOL_MANAGER"));
        address owner = vm.envAddress("RANGEPILOT_OWNER");

        bytes memory hookArgs = abi.encode(poolManager, owner);
        bytes memory hookInitCode = abi.encodePacked(type(ManagedLPHook).creationCode, hookArgs);

        vm.startBroadcast();
        hookDeployer = new HookCreate2Deployer();
        (bytes32 salt, address predictedHook) =
            HookMiner.find(address(hookDeployer), type(ManagedLPHook).creationCode, hookArgs);
        hook = ManagedLPHook(hookDeployer.deploy(salt, hookInitCode));
        require(address(hook) == predictedHook, "HOOK_ADDRESS_MISMATCH");

        implementation = new UserLPVault();
        factory = new VaultFactory(poolManager, hook, address(implementation));
        hook.setFactory(address(factory));
        vm.stopBroadcast();

        console2.log("HookCreate2Deployer", address(hookDeployer));
        console2.log("ManagedLPHook", address(hook));
        console2.log("UserLPVault implementation", address(implementation));
        console2.log("VaultFactory", address(factory));
        console2.log("PoolManager", address(poolManager));
        console2.log("Owner", owner);

        string memory object = "rangepilot";
        vm.serializeAddress(object, "hookCreate2Deployer", address(hookDeployer));
        vm.serializeAddress(object, "managedLPHook", address(hook));
        vm.serializeAddress(object, "userLPVaultImplementation", address(implementation));
        vm.serializeAddress(object, "vaultFactory", address(factory));
        vm.serializeAddress(object, "poolManager", address(poolManager));
        string memory json = vm.serializeAddress(object, "owner", owner);
        vm.writeJson(json, "deployments/rangepilot-latest.json");
    }
}
