// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {ManagedLPHook} from "../../src/ManagedLPHook.sol";

abstract contract HookDeployer {
    uint160 internal constant HOOK_MASK = (uint160(1) << 14) - 1;
    uint160 internal constant RANGE_PILOT_FLAGS = (uint160(1) << 11) | (uint160(1) << 9) | (uint160(1) << 6);

    function _deployManagedLPHook(IPoolManager poolManager, address owner) internal returns (ManagedLPHook hook) {
        bytes32 initCodeHash =
            keccak256(abi.encodePacked(type(ManagedLPHook).creationCode, abi.encode(poolManager, owner)));

        for (uint256 i = 0; i < 1_000_000; i++) {
            bytes32 salt = bytes32(i);
            address predicted = _computeCreate2Address(address(this), salt, initCodeHash);
            if (uint160(predicted) & HOOK_MASK == RANGE_PILOT_FLAGS) {
                hook = new ManagedLPHook{salt: salt}(poolManager, owner);
                return hook;
            }
        }

        revert("HOOK_SALT_NOT_FOUND");
    }

    function _computeCreate2Address(address deployer, bytes32 salt, bytes32 initCodeHash)
        internal
        pure
        returns (address)
    {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash)))));
    }
}
