// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {TransientStateLibrary} from "@uniswap/v4-core/src/libraries/TransientStateLibrary.sol";
import {
    ActivePosition,
    PoolBalance,
    RebalancePlan,
    StrategyConfig,
    WithdrawPlan
} from "./libraries/RangePilotTypes.sol";
import {IRangePilotVault} from "./interfaces/IRangePilotVault.sol";

contract UserLPVault is Initializable, ReentrancyGuard, IUnlockCallback, IRangePilotVault {
    using BalanceDeltaLibrary for BalanceDelta;
    using SafeERC20 for IERC20;
    using StateLibrary for IPoolManager;
    using TransientStateLibrary for IPoolManager;

    uint16 public constant MAX_BPS = 10_000;

    address public owner;
    address public aiOperator;
    address public factory;
    address public hook;
    IPoolManager public poolManager;

    PoolId[] private _poolIds;
    mapping(PoolId poolId => PoolAccount account) private _pools;
    mapping(PoolId poolId => mapping(uint256 nonce => bool used)) public usedNonces;

    struct PoolAccount {
        bool enabled;
        PoolKey key;
        StrategyConfig strategyConfig;
        ActivePosition activePosition;
        PoolBalance balance;
        uint256 lastRebalanceTimestamp;
    }

    enum CallbackAction {
        Rebalance,
        Withdraw,
        EmergencyExit,
        CollectFees
    }

    struct CallbackData {
        CallbackAction action;
        PoolId poolId;
        RebalancePlan rebalancePlan;
        WithdrawPlan withdrawPlan;
    }

    event PoolAdded(
        PoolId indexed poolId, address indexed token0, address indexed token1, uint24 fee, int24 tickSpacing
    );
    event Deposited(PoolId indexed poolId, address indexed owner, uint256 amount0, uint256 amount1);
    event Rebalanced(
        PoolId indexed poolId,
        address indexed operator,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidityRemoved,
        uint128 liquidityAdded,
        uint256 nonce,
        bytes32 reasonHash
    );
    event FeesCollected(PoolId indexed poolId, uint256 amount0, uint256 amount1);
    event Withdrawn(PoolId indexed poolId, address indexed owner, uint256 amount0, uint256 amount1);
    event EmergencyExited(PoolId indexed poolId, address indexed owner, uint256 amount0, uint256 amount1);
    event StrategyConfigUpdated(PoolId indexed poolId, StrategyConfig config);
    event AIOperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event AIOperatorRevoked(address indexed previousOperator);

    error NotOwner();
    error NotOperator();
    error NotFactory();
    error NotPoolManager();
    error ZeroAddress();
    error NativeCurrencyUnsupported();
    error InvalidPoolHook();
    error InvalidConfig();
    error InvalidPlan();
    error DeadlineExpired();
    error NonceAlreadyUsed();
    error CooldownActive();
    error PoolAlreadyEnabled(PoolId poolId);
    error PoolNotEnabled(PoolId poolId);
    error InvalidTickRange();
    error TickMoveTooLarge();
    error OutOfRangePosition();
    error InsufficientLiquidity();
    error InsufficientIdleBalance();
    error SlippageExceeded();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOperatorOrOwner() {
        if (msg.sender != aiOperator && msg.sender != owner) revert NotOperator();
        _;
    }

    modifier onlyFactory() {
        if (msg.sender != factory) revert NotFactory();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initializeFromFactory(
        address owner_,
        address aiOperator_,
        address factory_,
        address hook_,
        IPoolManager poolManager_
    ) external initializer {
        if (address(poolManager_) == address(0)) revert ZeroAddress();
        if (owner_ == address(0) || factory_ == address(0) || hook_ == address(0)) revert ZeroAddress();

        owner = owner_;
        aiOperator = aiOperator_;
        factory = factory_;
        hook = hook_;
        poolManager = poolManager_;

        emit AIOperatorUpdated(address(0), aiOperator_);
    }

    function addPool(PoolKey calldata key, StrategyConfig calldata config_) external onlyFactory returns (PoolId id) {
        _validatePoolKey(key);
        _validateConfig(config_);

        id = key.toId();
        if (_pools[id].enabled) revert PoolAlreadyEnabled(id);

        PoolAccount storage account = _pools[id];
        account.enabled = true;
        account.key = key;
        account.strategyConfig = config_;
        _poolIds.push(id);

        emit PoolAdded(id, Currency.unwrap(key.currency0), Currency.unwrap(key.currency1), key.fee, key.tickSpacing);
        emit StrategyConfigUpdated(id, config_);
    }

    function poolCount() external view returns (uint256) {
        return _poolIds.length;
    }

    function poolIdAt(uint256 index) external view returns (PoolId) {
        return _poolIds[index];
    }

    function isPoolEnabled(PoolId id) public view returns (bool) {
        return _pools[id].enabled;
    }

    function getPoolKey(PoolId id) external view returns (PoolKey memory) {
        return _pool(id).key;
    }

    function getStrategyConfig(PoolId id) external view returns (StrategyConfig memory) {
        return _pool(id).strategyConfig;
    }

    function getActivePosition(PoolId id) external view returns (ActivePosition memory) {
        return _pool(id).activePosition;
    }

    function getPoolBalance(PoolId id) external view returns (PoolBalance memory) {
        return _pool(id).balance;
    }

    function lastRebalanceTimestamp(PoolId id) external view returns (uint256) {
        return _pool(id).lastRebalanceTimestamp;
    }

    function deposit(PoolId id, uint256 amount0, uint256 amount1) external nonReentrant onlyOwner {
        PoolAccount storage account = _pool(id);
        if (amount0 == 0 && amount1 == 0) revert InvalidPlan();

        if (amount0 > 0) {
            _token0(account.key).safeTransferFrom(msg.sender, address(this), amount0);
            account.balance.idle0 += amount0;
        }
        if (amount1 > 0) {
            _token1(account.key).safeTransferFrom(msg.sender, address(this), amount1);
            account.balance.idle1 += amount1;
        }

        emit Deposited(id, msg.sender, amount0, amount1);
    }

    function rebalance(RebalancePlan calldata plan)
        external
        nonReentrant
        onlyOperatorOrOwner
        returns (int256 amount0Delta, int256 amount1Delta)
    {
        PoolAccount storage account = _pool(plan.poolId);
        _validateRebalancePlan(account, plan);
        usedNonces[plan.poolId][plan.nonce] = true;
        account.lastRebalanceTimestamp = block.timestamp;

        bytes memory result = poolManager.unlock(abi.encode(_rebalanceCallback(plan)));
        (amount0Delta, amount1Delta) = abi.decode(result, (int256, int256));

        emit Rebalanced(
            plan.poolId,
            msg.sender,
            plan.newTickLower,
            plan.newTickUpper,
            plan.liquidityToRemove,
            plan.liquidityToAdd,
            plan.nonce,
            plan.reasonHash
        );
    }

    function collectFees(PoolId id)
        external
        nonReentrant
        onlyOperatorOrOwner
        returns (uint256 amount0, uint256 amount1)
    {
        PoolAccount storage account = _pool(id);
        if (account.activePosition.liquidity == 0) return (0, 0);

        bytes memory result = poolManager.unlock(abi.encode(_collectCallback(id)));
        (amount0, amount1) = abi.decode(result, (uint256, uint256));
        emit FeesCollected(id, amount0, amount1);
    }

    function withdraw(WithdrawPlan calldata plan)
        external
        nonReentrant
        onlyOwner
        returns (uint256 amount0, uint256 amount1)
    {
        PoolAccount storage account = _pool(plan.poolId);
        if (block.timestamp > plan.deadline) revert DeadlineExpired();

        if (account.activePosition.liquidity > 0) {
            poolManager.unlock(abi.encode(_withdrawCallback(plan)));
        }

        if (account.balance.idle0 < plan.amount0Min || account.balance.idle1 < plan.amount1Min) {
            revert SlippageExceeded();
        }

        (amount0, amount1) = _transferPoolBalanceTo(account, owner);
        emit Withdrawn(plan.poolId, owner, amount0, amount1);
    }

    function emergencyExit(PoolId id) external nonReentrant onlyOwner returns (uint256 amount0, uint256 amount1) {
        PoolAccount storage account = _pool(id);
        if (account.activePosition.liquidity > 0) {
            poolManager.unlock(abi.encode(_emergencyCallback(id)));
        }
        (amount0, amount1) = _transferPoolBalanceTo(account, owner);
        emit EmergencyExited(id, owner, amount0, amount1);
    }

    function updateStrategyConfig(PoolId id, StrategyConfig calldata newConfig) external onlyOwner {
        PoolAccount storage account = _pool(id);
        _validateConfig(newConfig);
        account.strategyConfig = newConfig;
        emit StrategyConfigUpdated(id, newConfig);
    }

    function updateAIOperator(address newOperator) external onlyOwner {
        address oldOperator = aiOperator;
        aiOperator = newOperator;
        emit AIOperatorUpdated(oldOperator, newOperator);
    }

    function revokeAIOperator() external onlyOwner {
        address oldOperator = aiOperator;
        aiOperator = address(0);
        emit AIOperatorRevoked(oldOperator);
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        CallbackData memory callbackData = abi.decode(data, (CallbackData));

        if (callbackData.action == CallbackAction.Rebalance) {
            return _handleRebalance(callbackData.rebalancePlan);
        }
        if (callbackData.action == CallbackAction.Withdraw) {
            return _handleWithdraw(callbackData.withdrawPlan.poolId);
        }
        if (callbackData.action == CallbackAction.EmergencyExit) {
            return _handleWithdraw(callbackData.poolId);
        }
        if (callbackData.action == CallbackAction.CollectFees) {
            return _handleCollectFees(callbackData.poolId);
        }

        revert InvalidPlan();
    }

    function _handleRebalance(RebalancePlan memory plan) internal returns (bytes memory) {
        PoolAccount storage account = _pool(plan.poolId);
        ActivePosition memory oldPosition = account.activePosition;
        int256 amount0Removed;
        int256 amount1Removed;
        int256 amount0Added;
        int256 amount1Added;

        if (plan.liquidityToRemove > 0) {
            BalanceDelta removeDelta = _modifyLiquidity(
                account.key,
                oldPosition.tickLower,
                oldPosition.tickUpper,
                -int256(uint256(plan.liquidityToRemove)),
                oldPosition.salt,
                plan.reasonHash
            );
            uint256 amount0Received = _positive(removeDelta.amount0());
            uint256 amount1Received = _positive(removeDelta.amount1());
            if (amount0Received < plan.amount0Min || amount1Received < plan.amount1Min) {
                revert SlippageExceeded();
            }
            account.balance.idle0 += amount0Received;
            account.balance.idle1 += amount1Received;
            amount0Removed = int256(removeDelta.amount0());
            amount1Removed = int256(removeDelta.amount1());
        }

        if (plan.liquidityToAdd > 0) {
            bytes32 newSalt = _positionSalt(plan.poolId, plan.newTickLower, plan.newTickUpper);
            BalanceDelta addDelta = _modifyLiquidity(
                account.key,
                plan.newTickLower,
                plan.newTickUpper,
                int256(uint256(plan.liquidityToAdd)),
                newSalt,
                plan.reasonHash
            );
            uint256 amount0Spent = _negative(addDelta.amount0());
            uint256 amount1Spent = _negative(addDelta.amount1());
            if (amount0Spent > plan.amount0Max || amount1Spent > plan.amount1Max) revert SlippageExceeded();
            if (amount0Spent > account.balance.idle0 || amount1Spent > account.balance.idle1) {
                revert InsufficientIdleBalance();
            }

            account.balance.idle0 -= amount0Spent;
            account.balance.idle1 -= amount1Spent;
            amount0Added = int256(addDelta.amount0());
            amount1Added = int256(addDelta.amount1());
            account.activePosition = ActivePosition({
                tickLower: plan.newTickLower,
                tickUpper: plan.newTickUpper,
                liquidity: plan.liquidityToAdd,
                salt: newSalt
            });
        } else {
            delete account.activePosition;
        }

        _settleOpenDeltas(account.key);
        return abi.encode(amount0Removed + amount0Added, amount1Removed + amount1Added);
    }

    function _handleCollectFees(PoolId id) internal returns (bytes memory) {
        PoolAccount storage account = _pool(id);
        ActivePosition memory position = account.activePosition;
        BalanceDelta delta =
            _modifyLiquidity(account.key, position.tickLower, position.tickUpper, 0, position.salt, bytes32(0));
        uint256 amount0 = _positive(delta.amount0());
        uint256 amount1 = _positive(delta.amount1());
        account.balance.idle0 += amount0;
        account.balance.idle1 += amount1;
        _settleOpenDeltas(account.key);
        return abi.encode(amount0, amount1);
    }

    function _handleWithdraw(PoolId id) internal returns (bytes memory) {
        PoolAccount storage account = _pool(id);
        ActivePosition memory position = account.activePosition;
        if (position.liquidity == 0) return "";

        BalanceDelta delta = _modifyLiquidity(
            account.key,
            position.tickLower,
            position.tickUpper,
            -int256(uint256(position.liquidity)),
            position.salt,
            bytes32(0)
        );
        account.balance.idle0 += _positive(delta.amount0());
        account.balance.idle1 += _positive(delta.amount1());
        delete account.activePosition;
        _settleOpenDeltas(account.key);
        return "";
    }

    function _modifyLiquidity(
        PoolKey memory key,
        int24 tickLower,
        int24 tickUpper,
        int256 liquidityDelta,
        bytes32 salt,
        bytes32 reasonHash
    ) internal returns (BalanceDelta delta) {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: tickLower, tickUpper: tickUpper, liquidityDelta: liquidityDelta, salt: salt
        });
        (delta,) = poolManager.modifyLiquidity(key, params, abi.encode(reasonHash));
    }

    function _settleOpenDeltas(PoolKey memory key) internal {
        _settleCurrencyDelta(key.currency0);
        _settleCurrencyDelta(key.currency1);
    }

    function _settleCurrencyDelta(Currency currency) internal {
        int256 delta = poolManager.currencyDelta(address(this), currency);
        if (delta < 0) {
            _settle(currency, uint256(-delta));
        } else if (delta > 0) {
            poolManager.take(currency, address(this), uint256(delta));
        }
    }

    function _settle(Currency currency, uint256 amount) internal {
        if (amount == 0) return;
        poolManager.sync(currency);
        IERC20(Currency.unwrap(currency)).safeTransfer(address(poolManager), amount);
        poolManager.settle();
    }

    function _validateRebalancePlan(PoolAccount storage account, RebalancePlan calldata plan) internal view {
        if (block.timestamp > plan.deadline) revert DeadlineExpired();
        if (usedNonces[plan.poolId][plan.nonce]) revert NonceAlreadyUsed();
        if (
            account.lastRebalanceTimestamp != 0
                && block.timestamp < account.lastRebalanceTimestamp + account.strategyConfig.minRebalanceInterval
        ) revert CooldownActive();
        if (plan.liquidityToRemove > account.activePosition.liquidity) revert InsufficientLiquidity();
        if (account.activePosition.liquidity > 0 && plan.liquidityToRemove != account.activePosition.liquidity) {
            revert InvalidPlan();
        }
        if (plan.liquidityToAdd == 0 && plan.liquidityToRemove == 0) revert InvalidPlan();
        if (plan.amount0Min > plan.amount0Max || plan.amount1Min > plan.amount1Max) revert InvalidPlan();

        if (plan.liquidityToAdd > 0) {
            _validateRangeAgainstConfig(account, plan.poolId, plan.newTickLower, plan.newTickUpper);
            _validateTickMove(account, plan.newTickLower, plan.newTickUpper);
        }
    }

    function _validateRangeAgainstConfig(PoolAccount storage account, PoolId id, int24 tickLower, int24 tickUpper)
        internal
        view
    {
        _validateTicks(account.key, tickLower, tickUpper);
        int24 width = tickUpper - tickLower;
        if (width < account.strategyConfig.minWidth || width > account.strategyConfig.maxWidth) {
            revert InvalidTickRange();
        }

        if (!account.strategyConfig.allowOutOfRangePosition) {
            (, int24 currentTick,,) = poolManager.getSlot0(id);
            if (currentTick < tickLower || currentTick >= tickUpper) revert OutOfRangePosition();
        }
    }

    function _validateTickMove(PoolAccount storage account, int24 newTickLower, int24 newTickUpper) internal view {
        ActivePosition memory position = account.activePosition;
        if (position.liquidity == 0) return;

        int24 maxMove = account.strategyConfig.maxTickMovePerRebalance;
        if (_abs(newTickLower - position.tickLower) > uint24(maxMove)) revert TickMoveTooLarge();
        if (_abs(newTickUpper - position.tickUpper) > uint24(maxMove)) revert TickMoveTooLarge();
    }

    function _validatePoolKey(PoolKey calldata key) internal view {
        if (address(key.hooks) != hook) revert InvalidPoolHook();
        if (Currency.unwrap(key.currency0) == address(0) || Currency.unwrap(key.currency1) == address(0)) {
            revert NativeCurrencyUnsupported();
        }
    }

    function _validateTicks(PoolKey memory key, int24 tickLower, int24 tickUpper) internal pure {
        if (tickLower >= tickUpper) revert InvalidTickRange();
        if (tickLower < TickMath.MIN_TICK || tickUpper > TickMath.MAX_TICK) revert InvalidTickRange();
        if (tickLower % key.tickSpacing != 0 || tickUpper % key.tickSpacing != 0) revert InvalidTickRange();
    }

    function _validateConfig(StrategyConfig calldata config) internal pure {
        if (config.minWidth <= 0 || config.maxWidth < config.minWidth) revert InvalidConfig();
        if (config.maxTickMovePerRebalance <= 0) revert InvalidConfig();
        if (config.maxSlippageBps > MAX_BPS) revert InvalidConfig();
    }

    function _rebalanceCallback(RebalancePlan calldata plan) internal pure returns (CallbackData memory data) {
        data.action = CallbackAction.Rebalance;
        data.poolId = plan.poolId;
        data.rebalancePlan = plan;
    }

    function _withdrawCallback(WithdrawPlan calldata plan) internal pure returns (CallbackData memory data) {
        data.action = CallbackAction.Withdraw;
        data.poolId = plan.poolId;
        data.withdrawPlan = plan;
    }

    function _emergencyCallback(PoolId id) internal pure returns (CallbackData memory data) {
        data.action = CallbackAction.EmergencyExit;
        data.poolId = id;
    }

    function _collectCallback(PoolId id) internal pure returns (CallbackData memory data) {
        data.action = CallbackAction.CollectFees;
        data.poolId = id;
    }

    function _positionSalt(PoolId id, int24 tickLower, int24 tickUpper) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), id, tickLower, tickUpper));
    }

    function _transferPoolBalanceTo(PoolAccount storage account, address recipient)
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        amount0 = account.balance.idle0;
        amount1 = account.balance.idle1;
        account.balance.idle0 = 0;
        account.balance.idle1 = 0;

        if (amount0 > 0) _token0(account.key).safeTransfer(recipient, amount0);
        if (amount1 > 0) _token1(account.key).safeTransfer(recipient, amount1);
    }

    function _pool(PoolId id) internal view returns (PoolAccount storage account) {
        account = _pools[id];
        if (!account.enabled) revert PoolNotEnabled(id);
    }

    function _token0(PoolKey memory key) internal pure returns (IERC20) {
        return IERC20(Currency.unwrap(key.currency0));
    }

    function _token1(PoolKey memory key) internal pure returns (IERC20) {
        return IERC20(Currency.unwrap(key.currency1));
    }

    function _positive(int128 value) internal pure returns (uint256) {
        return value > 0 ? uint256(uint128(value)) : 0;
    }

    function _negative(int128 value) internal pure returns (uint256) {
        return value < 0 ? uint256(uint128(-value)) : 0;
    }

    function _abs(int24 value) internal pure returns (uint24) {
        return uint24(value < 0 ? -value : value);
    }
}
