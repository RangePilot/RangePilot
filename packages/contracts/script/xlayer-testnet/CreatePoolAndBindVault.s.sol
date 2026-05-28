// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {UserLPVault} from "../../src/UserLPVault.sol";
import {VaultFactory} from "../../src/VaultFactory.sol";
import {StrategyConfig} from "../../src/libraries/RangePilotTypes.sol";

contract CreateXLayerTestnetPoolAndBindVault is Script {
    using stdJson for string;
    using StateLibrary for IPoolManager;

    string internal constant OUTPUT_PATH = "deployments/xlayer-testnet.json";
    uint24 internal constant TESTNET_POOL_FEE = 100;
    int24 internal constant TESTNET_TICK_SPACING = 1;
    uint160 internal constant TESTNET_SQRT_PRICE_X96 = 79228162514264337593543950336;

    function run() external returns (PoolId poolId, int24 initialTick) {
        IPoolManager poolManager = IPoolManager(
            _configuredAddress({
                primaryEnv: "POOL_MANAGER",
                fallbackEnv: "XLAYER_TESTNET_POOL_MANAGER",
                firstJsonKey: ".uniswapV4.poolManager",
                secondJsonKey: ".rangePilot.poolManager",
                errorMessage: "POOL_MANAGER_NOT_SET"
            })
        );
        address hook = _configuredAddress({
            primaryEnv: "MANAGED_LP_HOOK",
            fallbackEnv: "XLAYER_TESTNET_MANAGED_LP_HOOK",
            firstJsonKey: ".rangePilot.managedLPHook",
            secondJsonKey: "",
            errorMessage: "MANAGED_LP_HOOK_NOT_SET"
        });
        VaultFactory factory = VaultFactory(
            _configuredAddress({
                primaryEnv: "VAULT_FACTORY",
                fallbackEnv: "XLAYER_TESTNET_VAULT_FACTORY",
                firstJsonKey: ".rangePilot.vaultFactory",
                secondJsonKey: "",
                errorMessage: "VAULT_FACTORY_NOT_SET"
            })
        );
        address vault = vm.envAddress("TESTNET_VAULT_ADDRESS");

        address vaultOwner = _validateVault(factory, poolManager, hook, vault);

        PoolKey memory key = _poolKey(hook);
        uint160 sqrtPriceX96 = TESTNET_SQRT_PRICE_X96;
        StrategyConfig memory config = _strategyConfig();
        poolId = key.toId();
        (uint160 currentSqrtPriceX96, int24 currentTick,,) = poolManager.getSlot0(poolId);
        bool poolAlreadyInitialized = currentSqrtPriceX96 != 0;
        bool vaultAlreadyBound = UserLPVault(vault).isPoolEnabled(poolId);

        vm.startBroadcast();
        (, address broadcaster,) = vm.readCallers();
        require(broadcaster == vaultOwner, "BROADCASTER_NOT_VAULT_OWNER");

        if (poolAlreadyInitialized) {
            initialTick = currentTick;
            sqrtPriceX96 = currentSqrtPriceX96;
        } else {
            initialTick = poolManager.initialize(key, sqrtPriceX96);
        }

        if (!vaultAlreadyBound) {
            PoolId addedPoolId = factory.addPoolToVault(key, config);
            require(PoolId.unwrap(addedPoolId) == PoolId.unwrap(poolId), "POOL_ID_MISMATCH");
        }
        vm.stopBroadcast();

        console2.log("Pool initialized and bound");
        console2.logBytes32(PoolId.unwrap(poolId));
        console2.log("Pool already initialized", poolAlreadyInitialized);
        console2.log("Vault already bound", vaultAlreadyBound);
        console2.log("Vault", vault);
        console2.log("Vault owner", vaultOwner);
        console2.log("VaultFactory", address(factory));
        console2.log("PoolManager", address(poolManager));
        console2.log("Hook", hook);
        console2.log("token0", Currency.unwrap(key.currency0));
        console2.log("token1", Currency.unwrap(key.currency1));
        console2.log("fee", key.fee);
        console2.log("tickSpacing", key.tickSpacing);
        console2.log("sqrtPriceX96", uint256(sqrtPriceX96));
        console2.log("initialTick", initialTick);

        _ensureBaseDeployment();
        _writeLatestPool(
            address(poolManager), hook, address(factory), vault, vaultOwner, key, poolId, sqrtPriceX96, initialTick
        );
    }

    function _poolKey(address hook) internal view returns (PoolKey memory key) {
        address tokenA = vm.envAddress("TESTNET_TOKEN_A");
        address tokenB = vm.envAddress("TESTNET_TOKEN_B");
        require(tokenA != tokenB, "IDENTICAL_TOKENS");

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: TESTNET_POOL_FEE,
            tickSpacing: TESTNET_TICK_SPACING,
            hooks: IHooks(hook)
        });
    }

    function _strategyConfig() internal view returns (StrategyConfig memory config) {
        config = StrategyConfig({
            minWidth: int24(vm.envOr("MIN_WIDTH", int256(60))),
            maxWidth: int24(vm.envOr("MAX_WIDTH", int256(600))),
            maxTickMovePerRebalance: int24(vm.envOr("MAX_TICK_MOVE_PER_REBALANCE", int256(120))),
            maxSlippageBps: uint16(vm.envOr("MAX_SLIPPAGE_BPS", uint256(500))),
            minRebalanceInterval: uint32(vm.envOr("MIN_REBALANCE_INTERVAL", uint256(1 hours))),
            allowOutOfRangePosition: vm.envOr("ALLOW_OUT_OF_RANGE_POSITION", false)
        });
    }

    function _validateVault(VaultFactory factory, IPoolManager poolManager, address hook, address vault)
        internal
        view
        returns (address vaultOwner)
    {
        require(vault != address(0), "TESTNET_VAULT_ADDRESS_NOT_SET");
        require(factory.isVault(vault), "VAULT_NOT_CREATED_BY_FACTORY");
        require(address(factory.poolManager()) == address(poolManager), "FACTORY_POOL_MANAGER_MISMATCH");
        require(address(factory.hook()) == hook, "FACTORY_HOOK_MISMATCH");

        UserLPVault userVault = UserLPVault(vault);
        vaultOwner = userVault.owner();

        require(factory.userVaults(vaultOwner) == vault, "VAULT_OWNER_FACTORY_MISMATCH");
        require(userVault.factory() == address(factory), "VAULT_FACTORY_MISMATCH");
        require(userVault.hook() == hook, "VAULT_HOOK_MISMATCH");
        require(address(userVault.poolManager()) == address(poolManager), "VAULT_POOL_MANAGER_MISMATCH");
    }

    function _configuredAddress(
        string memory primaryEnv,
        string memory fallbackEnv,
        string memory firstJsonKey,
        string memory secondJsonKey,
        string memory errorMessage
    ) internal view returns (address value) {
        value = vm.envOr(primaryEnv, address(0));
        if (value == address(0)) value = vm.envOr(fallbackEnv, address(0));

        if (value == address(0) && vm.isFile(OUTPUT_PATH)) {
            string memory json = vm.readFile(OUTPUT_PATH);
            if (json.keyExists(firstJsonKey)) {
                value = json.readAddress(firstJsonKey);
            } else if (bytes(secondJsonKey).length != 0 && json.keyExists(secondJsonKey)) {
                value = json.readAddress(secondJsonKey);
            }
        }

        require(value != address(0), errorMessage);
    }

    function _writeLatestPool(
        address poolManager,
        address hook,
        address factory,
        address vault,
        address vaultOwner,
        PoolKey memory key,
        PoolId poolId,
        uint160 sqrtPriceX96,
        int24 initialTick
    ) internal {
        string memory object = "latestPool";
        vm.serializeAddress(object, "poolManager", poolManager);
        vm.serializeAddress(object, "hook", hook);
        vm.serializeAddress(object, "vaultFactory", factory);
        vm.serializeAddress(object, "vault", vault);
        vm.serializeAddress(object, "vaultOwner", vaultOwner);
        vm.serializeAddress(object, "token0", Currency.unwrap(key.currency0));
        vm.serializeAddress(object, "token1", Currency.unwrap(key.currency1));
        vm.serializeUint(object, "fee", key.fee);
        vm.serializeInt(object, "tickSpacing", key.tickSpacing);
        vm.serializeString(object, "sqrtPriceX96", vm.toString(uint256(sqrtPriceX96)));
        vm.serializeInt(object, "tick", initialTick);
        string memory json = vm.serializeBytes32(object, "poolId", PoolId.unwrap(poolId));
        vm.writeJson(json, OUTPUT_PATH, ".latestPool");
    }

    function _ensureBaseDeployment() internal {
        if (vm.isFile(OUTPUT_PATH)) return;

        string memory object = "xlayer-testnet";
        vm.serializeString(object, "chain", "xlayer-testnet");
        string memory json = vm.serializeUint(object, "chainId", 1952);
        vm.writeJson(json, OUTPUT_PATH);
    }
}
