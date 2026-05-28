// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library HookMiner {
    uint160 internal constant HOOK_MASK = (uint160(1) << 14) - 1;
    uint160 internal constant RANGE_PILOT_FLAGS = (uint160(1) << 11) | (uint160(1) << 9) | (uint160(1) << 6);

    error SaltNotFound();

    function find(address deployer, bytes memory creationCode, bytes memory constructorArgs)
        internal
        pure
        returns (bytes32 salt, address predicted)
    {
        bytes32 initCodeHash = keccak256(abi.encodePacked(creationCode, constructorArgs));

        for (uint256 i = 0; i < 2_000_000; i++) {
            salt = bytes32(i);
            predicted = computeAddress(deployer, salt, initCodeHash);
            if (uint160(predicted) & HOOK_MASK == RANGE_PILOT_FLAGS) return (salt, predicted);
        }

        revert SaltNotFound();
    }

    function computeAddress(address deployer, bytes32 salt, bytes32 initCodeHash) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash)))));
    }
}
