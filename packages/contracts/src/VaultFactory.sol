// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {ManagedLPHook} from "./ManagedLPHook.sol";
import {UserLPVault} from "./UserLPVault.sol";
import {StrategyConfig} from "./libraries/RangePilotTypes.sol";

contract VaultFactory {
    using Clones for address;

    IPoolManager public immutable poolManager;
    ManagedLPHook public immutable hook;
    address public immutable vaultImplementation;

    mapping(address owner => address vault) public userVaults;
    mapping(address vault => bool valid) public isVault;

    event VaultCreated(
        address indexed owner, address indexed aiOperator, address indexed vault, address implementation
    );
    event PoolAddedToVault(address indexed owner, address indexed vault, PoolId indexed poolId);

    error ZeroAddress();
    error NotOwner();
    error VaultAlreadyExists(address owner, address vault);
    error VaultNotFound(address owner);
    error InvalidPoolHook();

    constructor(IPoolManager poolManager_, ManagedLPHook hook_, address vaultImplementation_) {
        if (address(poolManager_) == address(0) || address(hook_) == address(0) || vaultImplementation_ == address(0)) {
            revert ZeroAddress();
        }
        poolManager = poolManager_;
        hook = hook_;
        vaultImplementation = vaultImplementation_;
    }

    function createVault(address owner_, address aiOperator_) external returns (address vault) {
        if (owner_ == address(0)) revert ZeroAddress();
        if (msg.sender != owner_) revert NotOwner();

        vault = _createVault(owner_, aiOperator_);
    }

    function createVaultAndAddPool(
        address owner_,
        address aiOperator_,
        PoolKey calldata key,
        StrategyConfig calldata config
    ) external returns (address vault, PoolId poolId) {
        if (owner_ == address(0)) revert ZeroAddress();
        if (msg.sender != owner_) revert NotOwner();

        vault = _createVault(owner_, aiOperator_);
        poolId = _addPool(owner_, vault, key, config);
    }

    function addPoolToVault(PoolKey calldata key, StrategyConfig calldata config) external returns (PoolId poolId) {
        address vault = userVaults[msg.sender];
        if (vault == address(0)) revert VaultNotFound(msg.sender);

        poolId = _addPool(msg.sender, vault, key, config);
    }

    function _createVault(address owner_, address aiOperator_) internal returns (address vault) {
        if (userVaults[owner_] != address(0)) revert VaultAlreadyExists(owner_, userVaults[owner_]);
        vault = vaultImplementation.clone();
        UserLPVault(vault).initializeFromFactory(owner_, aiOperator_, address(this), address(hook), poolManager);

        userVaults[owner_] = vault;
        isVault[vault] = true;

        emit VaultCreated(owner_, aiOperator_, vault, vaultImplementation);
    }

    function _addPool(address owner_, address vault, PoolKey calldata key, StrategyConfig calldata config)
        internal
        returns (PoolId poolId)
    {
        if (address(key.hooks) != address(hook)) revert InvalidPoolHook();

        poolId = UserLPVault(vault).addPool(key, config);
        hook.registerVault(vault, key);

        emit PoolAddedToVault(owner_, vault, poolId);
    }
}
