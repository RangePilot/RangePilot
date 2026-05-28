import { useEffect, useId, useMemo, useRef, useState, type FormEvent } from 'react'
import { CheckCircle, CircleNotch, Coins } from '@phosphor-icons/react'
import { BaseError, formatUnits, parseUnits, zeroAddress, type Address, type Hash } from 'viem'
import { useReadContract, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'
import { erc20Abi, userLPVaultAbi } from '../contracts/abis'
import type { PoolPortfolio } from '../hooks/useVaultPortfolio'
import { explorerTransaction } from '../utils/explorer'
import { formatAddress, formatPoolId, formatTokenAmount } from '../utils/format'

type TransactionKind = 'approve0' | 'approve1' | 'deposit'

type ParsedAmount = {
  amount: bigint
  error?: string
}

type PoolDepositFormProps = {
  pool: PoolPortfolio
  owner?: Address
  vaultAddress?: Address
  chainId: number
  isWalletOnSelectedChain: boolean
  isSwitchPending: boolean
  onSwitchChain: () => void
  onDeposit: () => void | Promise<unknown>
}

export function PoolDepositForm({
  pool,
  owner,
  vaultAddress,
  chainId,
  isWalletOnSelectedChain,
  isSwitchPending,
  onSwitchChain,
  onDeposit,
}: PoolDepositFormProps) {
  const formId = useId()
  const token0Address = pool.key?.currency0
  const token1Address = pool.key?.currency1
  const token0Decimals = pool.token0?.decimals
  const token1Decimals = pool.token1?.decimals
  const token0Label = tokenLabel(pool, 'token0')
  const token1Label = tokenLabel(pool, 'token1')
  const [amount0Input, setAmount0Input] = useState('')
  const [amount1Input, setAmount1Input] = useState('')
  const [transactionKind, setTransactionKind] = useState<TransactionKind>()
  const handledHash = useRef<Hash | undefined>(undefined)
  const submittedKind = useRef<TransactionKind | undefined>(undefined)

  const amount0State = useMemo(() => parseDepositAmount(amount0Input, token0Decimals, token0Label), [
    amount0Input,
    token0Decimals,
    token0Label,
  ])
  const amount1State = useMemo(() => parseDepositAmount(amount1Input, token1Decimals, token1Label), [
    amount1Input,
    token1Decimals,
    token1Label,
  ])
  const amount0 = amount0State.amount
  const amount1 = amount1State.amount
  const hasAmount = amount0 > 0n || amount1 > 0n
  const canReadToken0 = Boolean(owner && vaultAddress && token0Address && token0Decimals !== undefined)
  const canReadToken1 = Boolean(owner && vaultAddress && token1Address && token1Decimals !== undefined)

  const token0Balance = useReadContract({
    address: token0Address ?? zeroAddress,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [owner ?? zeroAddress],
    chainId,
    query: {
      enabled: canReadToken0,
    },
  })
  const token1Balance = useReadContract({
    address: token1Address ?? zeroAddress,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [owner ?? zeroAddress],
    chainId,
    query: {
      enabled: canReadToken1,
    },
  })
  const token0Allowance = useReadContract({
    address: token0Address ?? zeroAddress,
    abi: erc20Abi,
    functionName: 'allowance',
    args: [owner ?? zeroAddress, vaultAddress ?? zeroAddress],
    chainId,
    query: {
      enabled: canReadToken0,
    },
  })
  const token1Allowance = useReadContract({
    address: token1Address ?? zeroAddress,
    abi: erc20Abi,
    functionName: 'allowance',
    args: [owner ?? zeroAddress, vaultAddress ?? zeroAddress],
    chainId,
    query: {
      enabled: canReadToken1,
    },
  })

  const { data: hash, error: writeError, isPending, writeContract } = useWriteContract()
  const {
    isLoading: isConfirming,
    isSuccess: isConfirmed,
    error: receiptError,
  } = useWaitForTransactionReceipt({
    hash,
    chainId,
  })

  const allowance0 = token0Allowance.data ?? 0n
  const allowance1 = token1Allowance.data ?? 0n
  const balance0 = token0Balance.data
  const balance1 = token1Balance.data
  const needsToken0Approval = amount0 > 0n && allowance0 < amount0
  const needsToken1Approval = amount1 > 0n && allowance1 < amount1
  const balanceError =
    balance0 !== undefined && amount0 > balance0
      ? `Insufficient ${token0Label} balance.`
      : balance1 !== undefined && amount1 > balance1
        ? `Insufficient ${token1Label} balance.`
        : undefined
  const amountError = amount0State.error ?? amount1State.error
  const formError = amountError ?? balanceError
  const buttonBusy = isPending || isConfirming
  const confirmedKind = isConfirmed ? transactionKind : undefined
  const primaryAction = needsToken0Approval
    ? ({ kind: 'approve0', label: `Approve ${token0Label}` } as const)
    : needsToken1Approval
      ? ({ kind: 'approve1', label: `Approve ${token1Label}` } as const)
      : ({ kind: 'deposit', label: 'Deposit' } as const)
  const canSubmit = Boolean(
    owner &&
      vaultAddress &&
      token0Address &&
      token1Address &&
      isWalletOnSelectedChain &&
      hasAmount &&
      !formError &&
      !buttonBusy,
  )

  useEffect(() => {
    if (!isConfirmed || !hash || handledHash.current === hash) {
      return
    }

    handledHash.current = hash

    void token0Balance.refetch()
    void token1Balance.refetch()
    void token0Allowance.refetch()
    void token1Allowance.refetch()

    if (submittedKind.current === 'deposit') {
      void onDeposit()
    }
  }, [
    hash,
    isConfirmed,
    onDeposit,
    token0Allowance,
    token0Balance,
    token1Allowance,
    token1Balance,
    transactionKind,
  ])

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()

    if (!isWalletOnSelectedChain) {
      onSwitchChain()
      return
    }

    if (!canSubmit || !vaultAddress || !token0Address || !token1Address) {
      return
    }

    setTransactionKind(primaryAction.kind)
    submittedKind.current = primaryAction.kind

    if (primaryAction.kind === 'approve0') {
      writeContract({
        address: token0Address,
        abi: erc20Abi,
        functionName: 'approve',
        args: [vaultAddress, amount0],
        chainId,
      })
      return
    }

    if (primaryAction.kind === 'approve1') {
      writeContract({
        address: token1Address,
        abi: erc20Abi,
        functionName: 'approve',
        args: [vaultAddress, amount1],
        chainId,
      })
      return
    }

    writeContract({
      address: vaultAddress,
      abi: userLPVaultAbi,
      functionName: 'deposit',
      args: [pool.poolId, amount0, amount1],
      chainId,
    })
  }

  function handleAmount0Change(value: string) {
    setAmount0Input(value)
    setTransactionKind(undefined)
  }

  function handleAmount1Change(value: string) {
    setAmount1Input(value)
    setTransactionKind(undefined)
  }

  return (
    <form className="deposit-form" onSubmit={handleSubmit}>
      <div className="deposit-inputs">
        <label htmlFor={`${formId}-token0`}>
          <span>{token0Label}</span>
          <input
            id={`${formId}-token0`}
            type="text"
            inputMode="decimal"
            value={amount0Input}
            placeholder="0"
            autoComplete="off"
            aria-invalid={Boolean(amount0State.error || balanceError?.includes(token0Label))}
            onChange={(event) => handleAmount0Change(event.target.value)}
          />
        </label>
        <label htmlFor={`${formId}-token1`}>
          <span>{token1Label}</span>
          <input
            id={`${formId}-token1`}
            type="text"
            inputMode="decimal"
            value={amount1Input}
            placeholder="0"
            autoComplete="off"
            aria-invalid={Boolean(amount1State.error || balanceError?.includes(token1Label))}
            onChange={(event) => handleAmount1Change(event.target.value)}
          />
        </label>
      </div>

      <div className="deposit-meta">
        <span>
          Wallet {formatTokenAmount(balance0, token0Decimals)} / {formatTokenAmount(balance1, token1Decimals)}
        </span>
        <span>
          Allowance {formatAllowance(allowance0, token0Decimals)} / {formatAllowance(allowance1, token1Decimals)}
        </span>
      </div>

      {!isWalletOnSelectedChain ? (
        <button type="submit" className="button button-secondary deposit-submit" disabled={isSwitchPending}>
          {isSwitchPending ? <CircleNotch className="spin" size={17} /> : <Coins size={17} weight="bold" />}
          Switch network
        </button>
      ) : (
        <button type="submit" className="button button-secondary deposit-submit" disabled={!canSubmit}>
          {buttonBusy ? (
            <CircleNotch className="spin" size={17} />
          ) : confirmedKind === 'deposit' ? (
            <CheckCircle size={17} weight="bold" />
          ) : (
            <Coins size={17} weight="bold" />
          )}
          {buttonLabel(primaryAction.label, transactionKind, isPending, isConfirming)}
        </button>
      )}

      {hash ? (
        <a className="text-link tx-link deposit-status" href={explorerTransaction(chainId, hash)} target="_blank" rel="noreferrer">
          {formatPoolId(hash)}
        </a>
      ) : null}
      {formError ? <p className="form-message form-error deposit-status">{formError}</p> : null}
      {confirmedKind ? <p className="form-message form-success deposit-status">{successMessage(confirmedKind)}</p> : null}
      {writeError || receiptError ? (
        <p className="form-message form-error deposit-status">{errorMessage(writeError ?? receiptError)}</p>
      ) : null}
    </form>
  )
}

function parseDepositAmount(input: string, decimals: number | undefined, tokenLabelText: string): ParsedAmount {
  const value = input.trim()

  if (!value) {
    return { amount: 0n }
  }

  if (!/^\d+(\.\d*)?$/.test(value)) {
    return { amount: 0n, error: `Enter a valid ${tokenLabelText} amount.` }
  }

  if (decimals === undefined) {
    return { amount: 0n, error: `${tokenLabelText} decimals are unavailable.` }
  }

  try {
    return { amount: parseUnits(value, decimals) }
  } catch {
    return { amount: 0n, error: `${tokenLabelText} supports up to ${decimals} decimals.` }
  }
}

function buttonLabel(label: string, kind: TransactionKind | undefined, isPending: boolean, isConfirming: boolean) {
  if (isConfirming) {
    return kind?.startsWith('approve') ? 'Confirming approval' : 'Confirming deposit'
  }

  if (isPending) {
    return kind?.startsWith('approve') ? 'Approving' : 'Depositing'
  }

  return label
}

function successMessage(kind: TransactionKind) {
  return kind === 'deposit' ? 'Deposit complete.' : 'Approval complete.'
}

function formatAllowance(value: bigint | undefined, decimals: number | undefined) {
  if (value === undefined) {
    return '-'
  }

  if (decimals === undefined) {
    return value.toString()
  }

  return formatUnits(value, decimals)
}

function errorMessage(error: unknown) {
  if (error instanceof BaseError) {
    return error.shortMessage
  }

  if (error instanceof Error) {
    return error.message
  }

  return 'Transaction failed.'
}

function tokenLabel(pool: PoolPortfolio, side: 'token0' | 'token1') {
  const token = pool[side]
  if (token?.symbol) {
    return token.symbol
  }

  const address = side === 'token0' ? pool.key?.currency0 : pool.key?.currency1
  return formatAddress(address as Address | undefined)
}
