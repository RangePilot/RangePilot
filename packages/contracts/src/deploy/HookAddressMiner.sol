// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

library HookAddressMiner {
    error HookAddressNotFound();

    function find(address deployer, bytes memory creationCode, bytes memory constructorArgs)
        internal
        pure
        returns (bytes32 salt, address hook)
    {
        bytes32 initCodeHash = keccak256(abi.encodePacked(creationCode, constructorArgs));
        uint160 requiredFlags =
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG;
        uint160 allHookMask = Hooks.ALL_HOOK_MASK;

        for (uint256 i; i < type(uint32).max; i++) {
            salt = bytes32(i);
            hook = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash)))));

            if (uint160(hook) & allHookMask == requiredFlags) {
                return (salt, hook);
            }
        }

        revert HookAddressNotFound();
    }
}
