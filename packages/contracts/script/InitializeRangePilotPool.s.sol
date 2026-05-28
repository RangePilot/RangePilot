// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

contract InitializeRangePilotPool is Script {
    function run() external returns (PoolKey memory key, int24 initialTick) {
        IPoolManager poolManager = IPoolManager(vm.envAddress("POOL_MANAGER"));
        address hook = vm.envAddress("MANAGED_LP_HOOK");
        address tokenA = vm.envAddress("TOKEN_A");
        address tokenB = vm.envAddress("TOKEN_B");
        uint24 fee = uint24(vm.envUint("POOL_FEE"));
        int24 tickSpacing = int24(int256(vm.envInt("TICK_SPACING")));
        uint160 sqrtPriceX96 = uint160(vm.envUint("SQRT_PRICE_X96"));

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(hook)
        });

        vm.startBroadcast();
        initialTick = poolManager.initialize(key, sqrtPriceX96);
        vm.stopBroadcast();

        console2.log("Pool initialized");
        console2.log("token0", token0);
        console2.log("token1", token1);
        console2.log("initialTick", initialTick);
    }
}
