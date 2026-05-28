// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {StrategyConfig} from "../src/libraries/RangePilotTypes.sol";

contract CreateVault is Script {
    function run() external returns (address vault, PoolId poolId) {
        VaultFactory factory = VaultFactory(vm.envAddress("VAULT_FACTORY"));
        address owner = vm.envAddress("VAULT_OWNER");
        address aiOperator = vm.envAddress("AI_OPERATOR");
        address hook = vm.envAddress("MANAGED_LP_HOOK");
        address tokenA = vm.envAddress("TOKEN_A");
        address tokenB = vm.envAddress("TOKEN_B");
        uint24 fee = uint24(vm.envUint("POOL_FEE"));
        int24 tickSpacing = int24(int256(vm.envInt("TICK_SPACING")));

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(hook)
        });
        StrategyConfig memory config = StrategyConfig({
            minWidth: 60,
            maxWidth: 600,
            maxTickMovePerRebalance: 120,
            maxSlippageBps: 500,
            allowOutOfRangePosition: false
        });

        vm.startBroadcast();
        (vault, poolId) = factory.createVaultAndAddPool(owner, aiOperator, key, config);
        vm.stopBroadcast();

        console2.log("Vault", vault);
        console2.logBytes32(PoolId.unwrap(poolId));
        console2.log("Owner", owner);
        console2.log("AI operator", aiOperator);
    }
}
