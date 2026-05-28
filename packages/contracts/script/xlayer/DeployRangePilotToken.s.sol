// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {RangePilotToken} from "../../src/RangePilotToken.sol";

contract DeployXLayerRangePilotToken is Script {
    string internal constant OUTPUT_PATH = "deployments/xlayer.json";

    function run() external returns (RangePilotToken token) {
        vm.startBroadcast();
        token = new RangePilotToken();
        vm.stopBroadcast();

        console2.log("RangePilot token", address(token));
        console2.log("Name", token.name());
        console2.log("Symbol", token.symbol());
        console2.log("Decimals", token.decimals());
        console2.log("Initial supply", token.totalSupply());

        _ensureBaseDeployment();

        string memory object = "tokens";
        string memory json = vm.serializeAddress(object, "rangePilot", address(token));
        vm.writeJson(json, OUTPUT_PATH, ".tokens");
    }

    function _ensureBaseDeployment() internal {
        if (vm.isFile(OUTPUT_PATH)) return;

        string memory object = "xlayer";
        vm.serializeString(object, "chain", "xlayer");
        string memory json = vm.serializeUint(object, "chainId", 196);
        vm.writeJson(json, OUTPUT_PATH);
    }
}
