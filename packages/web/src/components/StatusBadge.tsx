import { CheckCircle, CircleNotch, LinkBreak, WarningCircle } from '@phosphor-icons/react'

export type StatusKind = 'good' | 'warn' | 'bad' | 'idle'

export function StatusBadge({ state, label }: { state: StatusKind; label: string }) {
  const Icon = state === 'good' ? CheckCircle : state === 'bad' ? LinkBreak : state === 'warn' ? WarningCircle : CircleNotch

  return (
    <span className={`status-badge status-${state}`}>
      <Icon size={14} weight="bold" />
      {label}
    </span>
  )
}
