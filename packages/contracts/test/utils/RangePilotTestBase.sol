// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {ManagedLPHook} from "../../src/ManagedLPHook.sol";
import {UserLPVault} from "../../src/UserLPVault.sol";
import {VaultFactory} from "../../src/VaultFactory.sol";
import {
    ActivePosition,
    PoolBalance,
    RebalancePlan,
    StrategyConfig,
    WithdrawPlan
} from "../../src/libraries/RangePilotTypes.sol";
import {HookDeployer} from "./HookDeployer.sol";
import {MockERC20} from "./MockERC20.sol";
import {TestLiquidityRouter} from "./TestLiquidityRouter.sol";

abstract contract RangePilotTestBase is Test, HookDeployer {
    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    address internal owner = address(0xA11CE);
    address internal operator = address(0xB0B);
    address internal other = address(0xCAFE);

    PoolManager internal manager;
    ManagedLPHook internal hook;
    UserLPVault internal implementation;
    VaultFactory internal factory;
    UserLPVault internal vault;
    MockERC20 internal token0;
    MockERC20 internal token1;
    PoolKey internal key;
    PoolKey internal secondKey;

    function setUpCore() internal {
        manager = new PoolManager(address(this));
        hook = _deployManagedLPHook(manager, address(this));
        implementation = new UserLPVault();
        factory = new VaultFactory(manager, hook, address(implementation));
        hook.setFactory(address(factory));

        MockERC20 tokenA = new MockERC20("Token A", "TKNA");
        MockERC20 tokenB = new MockERC20("Token B", "TKNB");
        (token0, token1) = address(tokenA) < address(tokenB) ? (tokenA, tokenB) : (tokenB, tokenA);

        key = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        manager.initialize(key, SQRT_PRICE_1_1);
    }

    function createFundedVault() internal {
        vm.startPrank(owner);
        (address vaultAddress,) = factory.createVaultAndAddPool(owner, operator, key, defaultConfig());
        vault = UserLPVault(vaultAddress);
        vm.stopPrank();

        fundVaultPool(key.toId(), 1_000_000 ether, 1_000_000 ether);
    }

    function createVaultOnly() internal {
        vm.prank(owner);
        vault = UserLPVault(factory.createVault(owner, operator));
    }

    function addPoolToVault(PoolKey memory poolKey) internal returns (PoolId poolId) {
        vm.prank(owner);
        poolId = factory.addPoolToVault(poolKey, defaultConfig());
    }

    function fundVaultPool(PoolId poolId, uint256 amount0, uint256 amount1) internal {
        token0.mint(owner, 1_000_000 ether);
        token1.mint(owner, 1_000_000 ether);

        vm.startPrank(owner);
        token0.approve(address(vault), amount0);
        token1.approve(address(vault), amount1);
        vault.deposit(poolId, amount0, amount1);
        vm.stopPrank();
    }

    function initializeSecondPoolWithSameTokens() internal returns (PoolKey memory poolKey) {
        poolKey = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 500,
            tickSpacing: 10,
            hooks: IHooks(address(hook))
        });
        manager.initialize(poolKey, SQRT_PRICE_1_1);
        secondKey = poolKey;
    }

    function defaultConfig() internal pure returns (StrategyConfig memory) {
        return StrategyConfig({
            minWidth: 60,
            maxWidth: 600,
            maxTickMovePerRebalance: 120,
            maxSlippageBps: 500,
            minRebalanceInterval: 1 hours,
            allowOutOfRangePosition: false
        });
    }

    function plan(int24 lower, int24 upper, uint128 removeLiquidity, uint128 addLiquidity, uint256 nonce)
        internal
        view
        returns (RebalancePlan memory)
    {
        return planFor(key.toId(), lower, upper, removeLiquidity, addLiquidity, nonce);
    }

    function planFor(
        PoolId poolId,
        int24 lower,
        int24 upper,
        uint128 removeLiquidity,
        uint128 addLiquidity,
        uint256 nonce
    ) internal view returns (RebalancePlan memory) {
        return RebalancePlan({
            poolId: poolId,
            newTickLower: lower,
            newTickUpper: upper,
            liquidityToRemove: removeLiquidity,
            liquidityToAdd: addLiquidity,
            amount0Min: 0,
            amount1Min: 0,
            amount0Max: 1_000_000 ether,
            amount1Max: 1_000_000 ether,
            deadline: block.timestamp + 30 days,
            nonce: nonce,
            reasonHash: keccak256("test-plan")
        });
    }

    function addInitialLiquidity() internal {
        vm.prank(operator);
        vault.rebalance(plan(-60, 60, 0, 1 ether, 1));
    }

    function addInitialLiquidityFor(PoolId poolId, uint256 nonce) internal {
        vm.prank(operator);
        vault.rebalance(planFor(poolId, -60, 60, 0, 1 ether, nonce));
    }

    function withdrawPlan() internal view returns (WithdrawPlan memory) {
        return withdrawPlanFor(key.toId());
    }

    function withdrawPlanFor(PoolId poolId) internal view returns (WithdrawPlan memory) {
        return WithdrawPlan({poolId: poolId, amount0Min: 0, amount1Min: 0, deadline: block.timestamp + 5 minutes});
    }

    function active() internal view returns (ActivePosition memory) {
        return activeFor(key.toId());
    }

    function activeFor(PoolId poolId) internal view returns (ActivePosition memory) {
        return vault.getActivePosition(poolId);
    }

    function balanceFor(PoolId poolId) internal view returns (PoolBalance memory) {
        return vault.getPoolBalance(poolId);
    }

    function unregisteredRouter() internal returns (TestLiquidityRouter router) {
        router = new TestLiquidityRouter(manager);
        token0.mint(address(router), 1_000_000 ether);
        token1.mint(address(router), 1_000_000 ether);
    }

    function addParams(int24 lower, int24 upper, uint128 liquidity)
        internal
        pure
        returns (ModifyLiquidityParams memory)
    {
        return ModifyLiquidityParams({
            tickLower: lower, tickUpper: upper, liquidityDelta: int256(uint256(liquidity)), salt: bytes32(0)
        });
    }
}
