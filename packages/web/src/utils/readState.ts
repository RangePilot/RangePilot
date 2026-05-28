import type { Address } from 'viem'
import type { StatusKind } from '../components/StatusBadge'

export type ReadState = {
  kind: StatusKind
  label: string
  detail: string
}

export function getReadState({
  isConnected,
  isMissingFactory,
  isLoading,
  isFetching,
  error,
  vaultAddress,
}: {
  isConnected: boolean
  isMissingFactory: boolean
  isLoading: boolean
  isFetching: boolean
  error: Error | null
  vaultAddress?: Address
}): ReadState {
  if (!isConnected) {
    return { kind: 'idle', label: 'Idle', detail: 'Waiting for wallet connection.' }
  }

  if (isMissingFactory) {
    return { kind: 'warn', label: 'Config', detail: 'VaultFactory is not configured for this network.' }
  }

  if (isLoading) {
    return { kind: 'idle', label: 'Reading', detail: 'Reading on-chain state.' }
  }

  if (error) {
    return { kind: 'bad', label: 'Error', detail: 'Unable to read on-chain data.' }
  }

  if (!vaultAddress) {
    return { kind: 'warn', label: 'No Vault', detail: 'This wallet has not created a RangePilot Vault.' }
  }

  return {
    kind: 'good',
    label: isFetching ? 'Refreshing' : 'Synced',
    detail: isFetching ? 'Refreshing in the background.' : 'Vault and LP positions are in sync.',
  }
}
