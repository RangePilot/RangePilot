// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {VaultFactory} from "../../src/VaultFactory.sol";

contract CreateXLayerTestnetVault is Script {
    using stdJson for string;

    string internal constant OUTPUT_PATH = "deployments/xlayer-testnet.json";

    function run() external returns (address vault) {
        VaultFactory factory = VaultFactory(_vaultFactory());
        address owner = vm.envAddress("VAULT_OWNER");
        address aiOperator = vm.envOr("AI_OPERATOR", address(0));

        vm.startBroadcast();
        vault = factory.createVault(owner, aiOperator);
        vm.stopBroadcast();

        console2.log("VaultFactory", address(factory));
        console2.log("Vault", vault);
        console2.log("Owner", owner);
        console2.log("AI operator", aiOperator);

        _ensureBaseDeployment();

        string memory object = "latestVault";
        vm.serializeAddress(object, "vaultFactory", address(factory));
        vm.serializeAddress(object, "owner", owner);
        vm.serializeAddress(object, "aiOperator", aiOperator);
        string memory json = vm.serializeAddress(object, "vault", vault);
        vm.writeJson(json, OUTPUT_PATH, ".latestVault");
    }

    function _vaultFactory() internal view returns (address vaultFactory) {
        vaultFactory = vm.envOr("VAULT_FACTORY", address(0));
        if (vaultFactory == address(0)) {
            vaultFactory = vm.envOr("XLAYER_TESTNET_VAULT_FACTORY", address(0));
        }
        if (vaultFactory == address(0)) {
            require(vm.isFile(OUTPUT_PATH), "XLAYER_TESTNET_DEPLOYMENT_NOT_FOUND");
            string memory json = vm.readFile(OUTPUT_PATH);
            require(json.keyExists(".rangePilot.vaultFactory"), "XLAYER_TESTNET_VAULT_FACTORY_NOT_FOUND");
            vaultFactory = json.readAddress(".rangePilot.vaultFactory");
        }
    }

    function _ensureBaseDeployment() internal {
        if (vm.isFile(OUTPUT_PATH)) return;

        string memory object = "xlayer-testnet";
        vm.serializeString(object, "chain", "xlayer-testnet");
        string memory json = vm.serializeUint(object, "chainId", 1952);
        vm.writeJson(json, OUTPUT_PATH);
    }
}
