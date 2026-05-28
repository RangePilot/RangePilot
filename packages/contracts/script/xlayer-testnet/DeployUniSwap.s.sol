// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {StateView} from "@uniswap/v4-periphery/src/lens/StateView.sol";

contract DeployXLayerTestnetUniswap is Script {
    string internal constant OUTPUT_PATH = "deployments/xlayer-testnet.json";

    function run() external returns (PoolManager poolManager, StateView stateView) {
        address initialOwner = vm.envAddress("V4_INITIAL_OWNER");

        vm.startBroadcast();
        poolManager = new PoolManager(initialOwner);
        stateView = new StateView(poolManager);
        vm.stopBroadcast();

        console2.log("PoolManager", address(poolManager));
        console2.log("StateView", address(stateView));
        console2.log("Initial owner", initialOwner);

        _writeBaseDeployment();
        _writeUniswapV4(address(poolManager), address(stateView), initialOwner);
    }

    function _writeBaseDeployment() internal {
        string memory object = "xlayer-testnet";
        vm.serializeString(object, "chain", "xlayer-testnet");
        string memory json = vm.serializeUint(object, "chainId", 1952);
        vm.writeJson(json, OUTPUT_PATH);
    }

    function _writeUniswapV4(address poolManager, address stateView, address initialOwner) internal {
        string memory object = "xlayer-testnet-uniswap-v4";
        vm.serializeAddress(object, "poolManager", poolManager);
        vm.serializeAddress(object, "stateView", stateView);
        string memory json = vm.serializeAddress(object, "initialOwner", initialOwner);
        vm.writeJson(json, OUTPUT_PATH, ".uniswapV4");
    }
}
