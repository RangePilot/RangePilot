import { Database } from '@phosphor-icons/react'
import type { Address } from 'viem'
import type { PoolPortfolio } from '../hooks/useVaultPortfolio'
import { explorerAddress } from '../utils/explorer'
import {
  formatAddress,
  formatBps,
  formatDuration,
  formatInteger,
  formatPercentFromFeeUnits,
  formatPoolId,
  formatTimestamp,
  formatTokenAmount,
} from '../utils/format'
import { StatusBadge, type StatusKind } from './StatusBadge'

export function PoolsPanel({ pools, isLoading, chainId }: { pools: PoolPortfolio[]; isLoading: boolean; chainId: number }) {
  if (isLoading) {
    return (
      <section className="panel pools-panel">
        <div className="panel-heading">
          <div>
            <p className="eyebrow">LP positions</p>
            <h2>Position list</h2>
          </div>
        </div>
        <div className="skeleton-list" aria-hidden="true">
          <span />
          <span />
          <span />
        </div>
      </section>
    )
  }

  return (
    <section className="panel pools-panel">
      <div className="panel-heading">
        <div>
          <p className="eyebrow">LP positions</p>
          <h2>Position list</h2>
        </div>
        <span className="muted">{pools.length} pools</span>
      </div>

      {pools.length === 0 ? (
        <div className="empty-inline">
          <Database size={24} weight="bold" />
          <p>No pools are attached to this Vault yet.</p>
        </div>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Pool</th>
                <th>Range</th>
                <th>Liquidity</th>
                <th>Idle Balance</th>
                <th>Risk Limits</th>
                <th>Hook</th>
              </tr>
            </thead>
            <tbody>
              {pools.map((pool) => (
                <PoolRow key={pool.poolId} pool={pool} chainId={chainId} />
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  )
}

function PoolRow({ pool, chainId }: { pool: PoolPortfolio; chainId: number }) {
  const rangeState = getRangeState(pool)
  const token0 = tokenLabel(pool, 'token0')
  const token1 = tokenLabel(pool, 'token1')

  return (
    <tr>
      <td>
        <div className="pool-cell">
          <a className="pool-id" href={explorerAddress(chainId, pool.key?.hooks)} target="_blank" rel="noreferrer">
            {formatPoolId(pool.poolId)}
          </a>
          <span className="pair-label">
            {token0} / {token1}
          </span>
          <span className="muted">
            {formatPercentFromFeeUnits(pool.key?.fee)} fee · spacing {pool.key?.tickSpacing ?? '-'}
          </span>
        </div>
      </td>
      <td>
        <StatusBadge state={rangeState.kind} label={rangeState.label} />
        <span className="range-text">
          {pool.active ? `${pool.active.tickLower} to ${pool.active.tickUpper}` : '-'}
        </span>
        <span className="muted">current {pool.slot0?.tick ?? '-'}</span>
      </td>
      <td>
        <strong>{formatInteger(pool.active?.liquidity)}</strong>
        <span className="muted">salt {formatPoolId(pool.active?.salt)}</span>
      </td>
      <td>
        <span>
          {formatTokenAmount(pool.balance?.idle0, pool.token0?.decimals)} {token0}
        </span>
        <span>
          {formatTokenAmount(pool.balance?.idle1, pool.token1?.decimals)} {token1}
        </span>
      </td>
      <td>
        <span>width {pool.strategy ? `${pool.strategy.minWidth}-${pool.strategy.maxWidth}` : '-'}</span>
        <span>
          move {pool.strategy?.maxTickMovePerRebalance ?? '-'} · slip {formatBps(pool.strategy?.maxSlippageBps)}
        </span>
        <span>cooldown {formatDuration(pool.strategy?.minRebalanceInterval)}</span>
      </td>
      <td>
        <StatusBadge state={pool.registered ? 'good' : 'warn'} label={pool.registered ? 'Registered' : 'Unchecked'} />
        <span className="muted">swaps {formatInteger(pool.swapCount)}</span>
        <span className="muted">rebalance {formatTimestamp(pool.lastRebalanceTimestamp)}</span>
      </td>
    </tr>
  )
}

function getRangeState(pool: PoolPortfolio): { kind: StatusKind; label: string } {
  if (!pool.active || pool.active.liquidity === 0n) {
    return { kind: 'idle', label: 'No position' }
  }

  if (!pool.slot0) {
    return { kind: 'warn', label: 'No slot0' }
  }

  if (pool.slot0.tick >= pool.active.tickLower && pool.slot0.tick <= pool.active.tickUpper) {
    return { kind: 'good', label: 'In range' }
  }

  return { kind: 'bad', label: 'Out of range' }
}

function tokenLabel(pool: PoolPortfolio, side: 'token0' | 'token1') {
  const token = pool[side]
  if (token?.symbol) {
    return token.symbol
  }

  const address = side === 'token0' ? pool.key?.currency0 : pool.key?.currency1
  return formatAddress(address as Address | undefined)
}
