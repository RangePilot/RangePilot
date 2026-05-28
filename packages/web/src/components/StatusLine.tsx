import { ArrowClockwise } from '@phosphor-icons/react'
import type { ReadState } from '../utils/readState'
import { StatusBadge } from './StatusBadge'

export function StatusLine({
  hasPortfolio,
  isConnected,
  isSwitchPending,
  isWalletOnSelectedChain,
  readState,
  selectedChainName,
  onRefresh,
  onSwitchChain,
}: {
  hasPortfolio: boolean
  isConnected: boolean
  isSwitchPending: boolean
  isWalletOnSelectedChain: boolean
  readState: ReadState
  selectedChainName: string
  onRefresh: () => void
  onSwitchChain: () => void
}) {
  return (
    <section className="status-line" aria-live="polite">
      <StatusBadge state={readState.kind} label={readState.label} />
      <span>{readState.detail}</span>
      {isConnected && !isWalletOnSelectedChain ? (
        <button type="button" className="inline-action" disabled={isSwitchPending} onClick={onSwitchChain}>
          Switch to {selectedChainName}
        </button>
      ) : null}
      {hasPortfolio ? (
        <button type="button" className="inline-action" onClick={onRefresh}>
          <ArrowClockwise size={15} weight="bold" />
          Refresh
        </button>
      ) : null}
    </section>
  )
}
