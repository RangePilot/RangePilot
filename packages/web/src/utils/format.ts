import { formatUnits } from 'viem'

export function formatAddress(value: string | undefined, visible = 4) {
  if (!value) {
    return '-'
  }

  return `${value.slice(0, visible + 2)}...${value.slice(-visible)}`
}

export function formatPoolId(value: string | undefined) {
  if (!value) {
    return '-'
  }

  return `${value.slice(0, 10)}...${value.slice(-8)}`
}

export function formatInteger(value: bigint | number | undefined) {
  if (value === undefined) {
    return '-'
  }

  const numeric = typeof value === 'bigint' ? Number(value) : value
  return new Intl.NumberFormat('en-US', {
    notation: numeric >= 1_000_000 ? 'compact' : 'standard',
    maximumFractionDigits: 2,
  }).format(numeric)
}

export function formatTokenAmount(value: bigint | undefined, decimals: number | undefined) {
  if (value === undefined) {
    return '-'
  }

  if (value === 0n) {
    return '0'
  }

  const text = decimals === undefined ? value.toString() : formatUnits(value, decimals)
  const [whole, fraction = ''] = text.split('.')
  const visibleFraction = fraction.slice(0, 4).replace(/0+$/, '')

  if (whole.length > 8) {
    return new Intl.NumberFormat('en-US', {
      notation: 'compact',
      maximumFractionDigits: 3,
    }).format(Number(text))
  }

  return visibleFraction ? `${whole}.${visibleFraction}` : whole
}

export function formatPercentFromFeeUnits(fee: number | undefined) {
  if (fee === undefined) {
    return '-'
  }

  return `${(fee / 10_000).toFixed(2)}%`
}

export function formatBps(bps: number | undefined) {
  if (bps === undefined) {
    return '-'
  }

  return `${(bps / 100).toFixed(2)}%`
}

export function formatDuration(seconds: number | undefined) {
  if (seconds === undefined) {
    return '-'
  }

  if (seconds < 60) {
    return `${seconds}s`
  }

  if (seconds < 3_600) {
    return `${Math.round(seconds / 60)}m`
  }

  if (seconds < 86_400) {
    return `${Math.round(seconds / 3_600)}h`
  }

  return `${Math.round(seconds / 86_400)}d`
}

export function formatTimestamp(value: bigint | undefined) {
  if (!value || value === 0n) {
    return '-'
  }

  return new Intl.DateTimeFormat('en-US', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(Number(value) * 1000))
}
