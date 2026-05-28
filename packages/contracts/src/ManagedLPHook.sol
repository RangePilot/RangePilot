// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BalanceDelta, BalanceDeltaLibrary} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IRangePilotVault} from "./interfaces/IRangePilotVault.sol";

contract ManagedLPHook is IHooks {
    using BalanceDeltaLibrary for BalanceDelta;
    using Hooks for IHooks;

    uint160 public constant HOOK_FLAGS =
        Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG;

    IPoolManager public immutable poolManager;
    address public owner;
    address public factory;

    mapping(PoolId poolId => mapping(address vault => bool registered)) public registeredVaultForPool;
    mapping(PoolId poolId => uint256 count) public swapCount;
    mapping(PoolId poolId => uint256 timestamp) public lastSwapTimestamp;

    event FactorySet(address indexed factory);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event VaultRegistered(PoolId indexed poolId, address indexed vault);
    event LiquidityAccessChecked(
        PoolId indexed poolId,
        address indexed vault,
        int24 tickLower,
        int24 tickUpper,
        int256 liquidityDelta,
        bytes32 salt
    );
    event SwapTelemetry(PoolId indexed poolId, address indexed sender, uint256 swapCount, uint256 timestamp);

    error NotOwner();
    error NotFactory();
    error NotPoolManager();
    error FactoryAlreadySet();
    error ZeroAddress();
    error InvalidPoolHook();
    error VaultNotRegistered(PoolId poolId, address vault);
    error VaultPoolNotEnabled(PoolId poolId, address vault);
    error InvalidTickRange();
    error UnexpectedHookCall();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    constructor(IPoolManager poolManager_, address owner_) {
        if (address(poolManager_) == address(0) || owner_ == address(0)) revert ZeroAddress();
        poolManager = poolManager_;
        owner = owner_;

        IHooks(address(this))
            .validateHookPermissions(
                Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: true,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: true,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            })
            );
    }

    function setFactory(address factory_) external onlyOwner {
        if (factory != address(0)) revert FactoryAlreadySet();
        if (factory_ == address(0)) revert ZeroAddress();
        factory = factory_;
        emit FactorySet(factory_);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function registerVault(address vault, PoolKey calldata key) external {
        if (msg.sender != factory) revert NotFactory();
        if (vault == address(0)) revert ZeroAddress();
        if (address(key.hooks) != address(this)) revert InvalidPoolHook();

        PoolId id = key.toId();
        if (!IRangePilotVault(vault).isPoolEnabled(id)) revert VaultPoolNotEnabled(id, vault);

        registeredVaultForPool[id][vault] = true;
        emit VaultRegistered(id, vault);
    }

    function beforeInitialize(address, PoolKey calldata, uint160) external pure returns (bytes4) {
        revert UnexpectedHookCall();
    }

    function afterInitialize(address, PoolKey calldata, uint160, int24) external pure returns (bytes4) {
        revert UnexpectedHookCall();
    }

    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata
    ) external onlyPoolManager returns (bytes4) {
        _checkLiquidityAccess(sender, key, params);
        return IHooks.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure returns (bytes4, BalanceDelta) {
        revert UnexpectedHookCall();
    }

    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata
    ) external onlyPoolManager returns (bytes4) {
        _checkLiquidityAccess(sender, key, params);
        return IHooks.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure returns (bytes4, BalanceDelta) {
        revert UnexpectedHookCall();
    }

    function beforeSwap(address, PoolKey calldata, SwapParams calldata, bytes calldata)
        external
        pure
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        revert UnexpectedHookCall();
    }

    function afterSwap(address sender, PoolKey calldata key, SwapParams calldata, BalanceDelta, bytes calldata)
        external
        onlyPoolManager
        returns (bytes4, int128)
    {
        if (address(key.hooks) != address(this)) revert InvalidPoolHook();
        PoolId id = key.toId();
        uint256 count = ++swapCount[id];
        lastSwapTimestamp[id] = block.timestamp;
        emit SwapTelemetry(id, sender, count, block.timestamp);
        return (IHooks.afterSwap.selector, 0);
    }

    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        revert UnexpectedHookCall();
    }

    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        revert UnexpectedHookCall();
    }

    function _checkLiquidityAccess(address sender, PoolKey calldata key, ModifyLiquidityParams calldata params)
        internal
    {
        if (address(key.hooks) != address(this)) revert InvalidPoolHook();
        _validateTicks(key, params.tickLower, params.tickUpper);

        PoolId id = key.toId();
        if (!registeredVaultForPool[id][sender]) revert VaultNotRegistered(id, sender);
        if (!IRangePilotVault(sender).isPoolEnabled(id)) revert VaultPoolNotEnabled(id, sender);

        emit LiquidityAccessChecked(id, sender, params.tickLower, params.tickUpper, params.liquidityDelta, params.salt);
    }

    function _validateTicks(PoolKey calldata key, int24 tickLower, int24 tickUpper) internal pure {
        if (tickLower >= tickUpper) revert InvalidTickRange();
        if (tickLower < TickMath.MIN_TICK || tickUpper > TickMath.MAX_TICK) revert InvalidTickRange();
        if (tickLower % key.tickSpacing != 0 || tickUpper % key.tickSpacing != 0) revert InvalidTickRange();
    }
}
