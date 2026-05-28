import { useQuery } from '@tanstack/react-query'
import { isAddress, zeroAddress, type Address, type Hex, type PublicClient } from 'viem'
import { usePublicClient } from 'wagmi'
import type { DeploymentConfig } from '../config/contracts'
import {
  erc20Abi,
  managedLPHookAbi,
  stateViewAbi,
  userLPVaultAbi,
  vaultFactoryAbi,
} from '../contracts/abis'

const MAX_POOLS_TO_LOAD = 24

export type PoolKeyData = {
  currency0: Address
  currency1: Address
  fee: number
  tickSpacing: number
  hooks: Address
}

export type StrategyConfigData = {
  minWidth: number
  maxWidth: number
  maxTickMovePerRebalance: number
  maxSlippageBps: number
  allowOutOfRangePosition: boolean
}

export type ActivePositionData = {
  tickLower: number
  tickUpper: number
  liquidity: bigint
  salt: Hex
}

export type PoolBalanceData = {
  idle0: bigint
  idle1: bigint
}

export type Slot0Data = {
  sqrtPriceX96: bigint
  tick: number
  protocolFee: number
  lpFee: number
}

export type TokenMeta = {
  address: Address
  symbol?: string
  decimals?: number
}

export type PoolPortfolio = {
  poolId: Hex
  enabled?: boolean
  registered?: boolean
  key?: PoolKeyData
  strategy?: StrategyConfigData
  active?: ActivePositionData
  balance?: PoolBalanceData
  slot0?: Slot0Data
  token0?: TokenMeta
  token1?: TokenMeta
  lastRebalanceTimestamp?: bigint
  swapCount?: bigint
  lastSwapTimestamp?: bigint
}

export type VaultPortfolio = {
  owner: Address
  vaultAddress?: Address
  vaultOwner?: Address
  aiOperator?: Address
  vaultFactory?: Address
  vaultHook?: Address
  vaultPoolManager?: Address
  poolCount: number
  loadedPoolCount: number
  truncated: boolean
  pools: PoolPortfolio[]
}

type UseVaultPortfolioParams = {
  owner?: Address
  chainId: number
  deployment: DeploymentConfig
}

export function useVaultPortfolio({ owner, chainId, deployment }: UseVaultPortfolioParams) {
  const publicClient = usePublicClient({ chainId })

  const query = useQuery({
    queryKey: [
      'vault-portfolio',
      chainId,
      owner,
      deployment.vaultFactory,
      deployment.managedLPHook,
      deployment.stateView,
    ],
    enabled: Boolean(owner && publicClient && deployment.vaultFactory),
    queryFn: () =>
      loadVaultPortfolio({
        chainId,
        client: publicClient as PublicClient,
        deployment,
        owner: owner as Address,
      }),
    refetchInterval: 30_000,
    staleTime: 15_000,
  })

  return {
    ...query,
    isMissingFactory: !deployment.vaultFactory,
  }
}

async function loadVaultPortfolio({
  client,
  deployment,
  owner,
}: {
  chainId: number
  client: PublicClient
  deployment: DeploymentConfig
  owner: Address
}): Promise<VaultPortfolio> {
  const vaultAddress = await safeRead<Address>(() =>
    client.readContract({
      address: deployment.vaultFactory as Address,
      abi: vaultFactoryAbi,
      functionName: 'userVaults',
      args: [owner],
    }),
  )

  if (!vaultAddress || vaultAddress === zeroAddress) {
    return {
      owner,
      poolCount: 0,
      loadedPoolCount: 0,
      truncated: false,
      pools: [],
    }
  }

  const [vaultOwner, aiOperator, vaultFactory, vaultHook, vaultPoolManager, poolCountRaw] =
    await Promise.all([
      safeRead<Address>(() =>
        client.readContract({ address: vaultAddress, abi: userLPVaultAbi, functionName: 'owner' }),
      ),
      safeRead<Address>(() =>
        client.readContract({ address: vaultAddress, abi: userLPVaultAbi, functionName: 'aiOperator' }),
      ),
      safeRead<Address>(() =>
        client.readContract({ address: vaultAddress, abi: userLPVaultAbi, functionName: 'factory' }),
      ),
      safeRead<Address>(() =>
        client.readContract({ address: vaultAddress, abi: userLPVaultAbi, functionName: 'hook' }),
      ),
      safeRead<Address>(() =>
        client.readContract({ address: vaultAddress, abi: userLPVaultAbi, functionName: 'poolManager' }),
      ),
      safeRead<bigint>(() =>
        client.readContract({ address: vaultAddress, abi: userLPVaultAbi, functionName: 'poolCount' }),
      ),
    ])

  const poolCount = Number(poolCountRaw ?? 0n)
  const loadedPoolCount = Math.min(poolCount, MAX_POOLS_TO_LOAD)
  const poolIds = await Promise.all(
    Array.from({ length: loadedPoolCount }, (_, index) =>
      safeRead<Hex>(() =>
        client.readContract({
          address: vaultAddress,
          abi: userLPVaultAbi,
          functionName: 'poolIdAt',
          args: [BigInt(index)],
        }),
      ),
    ),
  )

  const pools = await Promise.all(
    poolIds
      .filter((poolId): poolId is Hex => Boolean(poolId))
      .map((poolId) => loadPoolPortfolio(client, deployment, vaultAddress, poolId)),
  )

  return {
    owner,
    vaultAddress,
    vaultOwner,
    aiOperator,
    vaultFactory,
    vaultHook,
    vaultPoolManager,
    poolCount,
    loadedPoolCount: pools.length,
    truncated: poolCount > MAX_POOLS_TO_LOAD,
    pools,
  }
}

async function loadPoolPortfolio(
  client: PublicClient,
  deployment: DeploymentConfig,
  vaultAddress: Address,
  poolId: Hex,
): Promise<PoolPortfolio> {
  const [enabled, keyRaw, strategyRaw, activeRaw, balanceRaw, lastRebalanceTimestamp] =
    await Promise.all([
      safeRead<boolean>(() =>
        client.readContract({
          address: vaultAddress,
          abi: userLPVaultAbi,
          functionName: 'isPoolEnabled',
          args: [poolId],
        }),
      ),
      safeRead<unknown>(() =>
        client.readContract({
          address: vaultAddress,
          abi: userLPVaultAbi,
          functionName: 'getPoolKey',
          args: [poolId],
        }),
      ),
      safeRead<unknown>(() =>
        client.readContract({
          address: vaultAddress,
          abi: userLPVaultAbi,
          functionName: 'getStrategyConfig',
          args: [poolId],
        }),
      ),
      safeRead<unknown>(() =>
        client.readContract({
          address: vaultAddress,
          abi: userLPVaultAbi,
          functionName: 'getActivePosition',
          args: [poolId],
        }),
      ),
      safeRead<unknown>(() =>
        client.readContract({
          address: vaultAddress,
          abi: userLPVaultAbi,
          functionName: 'getPoolBalance',
          args: [poolId],
        }),
      ),
      safeRead<bigint>(() =>
        client.readContract({
          address: vaultAddress,
          abi: userLPVaultAbi,
          functionName: 'lastRebalanceTimestamp',
          args: [poolId],
        }),
      ),
    ])

  const key = parsePoolKey(keyRaw)
  const [registered, swapCount, lastSwapTimestamp, slot0, token0, token1] = await Promise.all([
    deployment.managedLPHook
      ? safeRead<boolean>(() =>
          client.readContract({
            address: deployment.managedLPHook as Address,
            abi: managedLPHookAbi,
            functionName: 'registeredVaultForPool',
            args: [poolId, vaultAddress],
          }),
        )
      : Promise.resolve(undefined),
    deployment.managedLPHook
      ? safeRead<bigint>(() =>
          client.readContract({
            address: deployment.managedLPHook as Address,
            abi: managedLPHookAbi,
            functionName: 'swapCount',
            args: [poolId],
          }),
        )
      : Promise.resolve(undefined),
    deployment.managedLPHook
      ? safeRead<bigint>(() =>
          client.readContract({
            address: deployment.managedLPHook as Address,
            abi: managedLPHookAbi,
            functionName: 'lastSwapTimestamp',
            args: [poolId],
          }),
        )
      : Promise.resolve(undefined),
    deployment.stateView
      ? safeRead<unknown>(() =>
          client.readContract({
            address: deployment.stateView as Address,
            abi: stateViewAbi,
            functionName: 'getSlot0',
            args: [poolId],
          }),
        ).then(parseSlot0)
      : Promise.resolve(undefined),
    key ? loadTokenMeta(client, key.currency0) : Promise.resolve(undefined),
    key ? loadTokenMeta(client, key.currency1) : Promise.resolve(undefined),
  ])

  return {
    poolId,
    enabled,
    registered,
    key,
    strategy: parseStrategyConfig(strategyRaw),
    active: parseActivePosition(activeRaw),
    balance: parsePoolBalance(balanceRaw),
    slot0,
    token0,
    token1,
    lastRebalanceTimestamp,
    swapCount,
    lastSwapTimestamp,
  }
}

async function loadTokenMeta(client: PublicClient, address: Address): Promise<TokenMeta> {
  const [symbolRaw, decimalsRaw] = await Promise.all([
    safeRead<string>(() =>
      client.readContract({
        address,
        abi: erc20Abi,
        functionName: 'symbol',
      }),
    ),
    safeRead<number>(() =>
      client.readContract({
        address,
        abi: erc20Abi,
        functionName: 'decimals',
      }),
    ),
  ])

  return {
    address,
    symbol: typeof symbolRaw === 'string' && symbolRaw.length <= 16 ? symbolRaw : undefined,
    decimals: toNumber(decimalsRaw),
  }
}

async function safeRead<T>(read: () => Promise<T>): Promise<T | undefined> {
  try {
    return await read()
  } catch {
    return undefined
  }
}

function parsePoolKey(value: unknown): PoolKeyData | undefined {
  const currency0 = toAddress(readField(value, 0, 'currency0'))
  const currency1 = toAddress(readField(value, 1, 'currency1'))
  const fee = toNumber(readField(value, 2, 'fee'))
  const tickSpacing = toNumber(readField(value, 3, 'tickSpacing'))
  const hooks = toAddress(readField(value, 4, 'hooks'))

  if (!currency0 || !currency1 || fee === undefined || tickSpacing === undefined || !hooks) {
    return undefined
  }

  return { currency0, currency1, fee, tickSpacing, hooks }
}

function parseStrategyConfig(value: unknown): StrategyConfigData | undefined {
  const minWidth = toNumber(readField(value, 0, 'minWidth'))
  const maxWidth = toNumber(readField(value, 1, 'maxWidth'))
  const maxTickMovePerRebalance = toNumber(readField(value, 2, 'maxTickMovePerRebalance'))
  const maxSlippageBps = toNumber(readField(value, 3, 'maxSlippageBps'))
  const allowOutOfRangePosition = toBoolean(readField(value, 4, 'allowOutOfRangePosition'))

  if (
    minWidth === undefined ||
    maxWidth === undefined ||
    maxTickMovePerRebalance === undefined ||
    maxSlippageBps === undefined ||
    allowOutOfRangePosition === undefined
  ) {
    return undefined
  }

  return {
    minWidth,
    maxWidth,
    maxTickMovePerRebalance,
    maxSlippageBps,
    allowOutOfRangePosition,
  }
}

function parseActivePosition(value: unknown): ActivePositionData | undefined {
  const tickLower = toNumber(readField(value, 0, 'tickLower'))
  const tickUpper = toNumber(readField(value, 1, 'tickUpper'))
  const liquidity = toBigInt(readField(value, 2, 'liquidity'))
  const salt = toHex(readField(value, 3, 'salt'))

  if (tickLower === undefined || tickUpper === undefined || liquidity === undefined || !salt) {
    return undefined
  }

  return { tickLower, tickUpper, liquidity, salt }
}

function parsePoolBalance(value: unknown): PoolBalanceData | undefined {
  const idle0 = toBigInt(readField(value, 0, 'idle0'))
  const idle1 = toBigInt(readField(value, 1, 'idle1'))

  if (idle0 === undefined || idle1 === undefined) {
    return undefined
  }

  return { idle0, idle1 }
}

function parseSlot0(value: unknown): Slot0Data | undefined {
  const sqrtPriceX96 = toBigInt(readField(value, 0, 'sqrtPriceX96'))
  const tick = toNumber(readField(value, 1, 'tick'))
  const protocolFee = toNumber(readField(value, 2, 'protocolFee'))
  const lpFee = toNumber(readField(value, 3, 'lpFee'))

  if (
    sqrtPriceX96 === undefined ||
    tick === undefined ||
    protocolFee === undefined ||
    lpFee === undefined
  ) {
    return undefined
  }

  return { sqrtPriceX96, tick, protocolFee, lpFee }
}

function readField(value: unknown, index: number, key: string): unknown {
  if (typeof value !== 'object' || value === null) {
    return undefined
  }

  const record = value as Record<string | number, unknown>
  return record[key] ?? record[index]
}

function toAddress(value: unknown): Address | undefined {
  return typeof value === 'string' && isAddress(value) ? (value as Address) : undefined
}

function toHex(value: unknown): Hex | undefined {
  return typeof value === 'string' && value.startsWith('0x') ? (value as Hex) : undefined
}

function toBoolean(value: unknown): boolean | undefined {
  return typeof value === 'boolean' ? value : undefined
}

function toNumber(value: unknown): number | undefined {
  if (typeof value === 'number') {
    return value
  }

  if (typeof value === 'bigint') {
    return Number(value)
  }

  return undefined
}

function toBigInt(value: unknown): bigint | undefined {
  if (typeof value === 'bigint') {
    return value
  }

  if (typeof value === 'number') {
    return BigInt(value)
  }

  return undefined
}
