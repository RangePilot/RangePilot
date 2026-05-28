// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {HookCreate2Deployer} from "../../src/deploy/HookCreate2Deployer.sol";
import {ManagedLPHook} from "../../src/ManagedLPHook.sol";
import {UserLPVault} from "../../src/UserLPVault.sol";
import {VaultFactory} from "../../src/VaultFactory.sol";
import {HookMiner} from "../HookMiner.sol";

contract DeployXLayerTestnetHookAndVault is Script {
    using stdJson for string;

    string internal constant OUTPUT_PATH = "deployments/xlayer-testnet.json";

    function run()
        external
        returns (HookCreate2Deployer hookDeployer, ManagedLPHook hook, UserLPVault implementation, VaultFactory factory)
    {
        IPoolManager poolManager = _poolManager();
        address stateView = _optionalAddress("STATE_VIEW", "XLAYER_TESTNET_STATE_VIEW", ".uniswapV4.stateView");
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
        if (stateView != address(0)) console2.log("StateView", stateView);
        console2.log("Owner", owner);

        _ensureBaseDeployment();

        string memory object = "rangePilot";
        vm.serializeAddress(object, "hookCreate2Deployer", address(hookDeployer));
        vm.serializeAddress(object, "managedLPHook", address(hook));
        vm.serializeAddress(object, "userLPVaultImplementation", address(implementation));
        vm.serializeAddress(object, "vaultFactory", address(factory));
        vm.serializeAddress(object, "poolManager", address(poolManager));
        if (stateView != address(0)) vm.serializeAddress(object, "stateView", stateView);
        string memory json = vm.serializeAddress(object, "owner", owner);
        vm.writeJson(json, OUTPUT_PATH, ".rangePilot");
    }

    function _poolManager() internal view returns (IPoolManager) {
        address poolManager = vm.envOr("POOL_MANAGER", address(0));
        if (poolManager == address(0)) {
            poolManager = vm.envOr("XLAYER_TESTNET_POOL_MANAGER", address(0));
        }
        if (poolManager == address(0)) {
            poolManager = _readDeploymentAddress(".uniswapV4.poolManager");
        }

        require(poolManager != address(0), "POOL_MANAGER_NOT_SET");
        return IPoolManager(poolManager);
    }

    function _optionalAddress(string memory primaryEnv, string memory fallbackEnv, string memory jsonKey)
        internal
        view
        returns (address value)
    {
        value = vm.envOr(primaryEnv, address(0));
        if (value == address(0)) value = vm.envOr(fallbackEnv, address(0));
        if (value == address(0) && vm.isFile(OUTPUT_PATH)) {
            string memory json = vm.readFile(OUTPUT_PATH);
            if (json.keyExists(jsonKey)) value = json.readAddress(jsonKey);
        }
    }

    function _readDeploymentAddress(string memory key) internal view returns (address) {
        require(vm.isFile(OUTPUT_PATH), "XLAYER_TESTNET_DEPLOYMENT_NOT_FOUND");
        string memory json = vm.readFile(OUTPUT_PATH);
        require(json.keyExists(key), "XLAYER_TESTNET_V4_KEY_NOT_FOUND");
        return json.readAddress(key);
    }

    function _ensureBaseDeployment() internal {
        if (vm.isFile(OUTPUT_PATH)) return;

        string memory object = "xlayer-testnet";
        vm.serializeString(object, "chain", "xlayer-testnet");
        string memory json = vm.serializeUint(object, "chainId", 1952);
        vm.writeJson(json, OUTPUT_PATH);
    }
}
