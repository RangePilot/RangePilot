import { useCallback, useEffect, useId, useMemo, useRef, useState, type FormEvent } from 'react'
import { CheckCircle, CircleNotch, Coins } from '@phosphor-icons/react'
import { BaseError, parseUnits, zeroAddress, type Address, type Hash } from 'viem'
import { useReadContract, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'
import { erc20Abi, userLPVaultAbi } from '../contracts/abis'
import type { PoolPortfolio } from '../hooks/useVaultPortfolio'
import { formatAddress } from '../utils/format'

type DepositStep =
  | {
      kind: 'approve0'
      tokenAddress: Address
      amount: bigint
    }
  | {
      kind: 'approve1'
      tokenAddress: Address
      amount: bigint
    }
  | {
      kind: 'deposit'
      amount0: bigint
      amount1: bigint
    }

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
  const [activeStepKind, setActiveStepKind] = useState<DepositStep['kind']>()
  const handledHash = useRef<Hash | undefined>(undefined)
  const activeStep = useRef<DepositStep | undefined>(undefined)
  const depositSteps = useRef<DepositStep[]>([])
  const depositStepIndex = useRef(0)

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
  const depositConfirmed = isConfirmed && activeStepKind === 'deposit'
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

  const runDepositStep = useCallback(
    (step: DepositStep) => {
      activeStep.current = step
      setActiveStepKind(step.kind)

      if (step.kind !== 'deposit') {
        writeContract({
          address: step.tokenAddress,
          abi: erc20Abi,
          functionName: 'approve',
          args: [vaultAddress as Address, step.amount],
          chainId,
        })
        return
      }

      writeContract({
        address: vaultAddress as Address,
        abi: userLPVaultAbi,
        functionName: 'deposit',
        args: [pool.poolId, step.amount0, step.amount1],
        chainId,
      })
    },
    [chainId, pool.poolId, vaultAddress, writeContract],
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

    if (activeStep.current?.kind === 'deposit') {
      void onDeposit()
      return
    }

    depositStepIndex.current += 1
    const nextStep = depositSteps.current[depositStepIndex.current]
    if (nextStep) {
      runDepositStep(nextStep)
    }
  }, [
    hash,
    isConfirmed,
    onDeposit,
    runDepositStep,
    token0Allowance,
    token0Balance,
    token1Allowance,
    token1Balance,
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

    const steps = buildDepositSteps({
      amount0,
      amount1,
      needsToken0Approval,
      needsToken1Approval,
      token0Address,
      token1Address,
    })

    depositSteps.current = steps
    depositStepIndex.current = 0
    handledHash.current = undefined

    const firstStep = steps[0]
    if (firstStep) {
      runDepositStep(firstStep)
    }
  }

  function handleAmount0Change(value: string) {
    setAmount0Input(value)
    setActiveStepKind(undefined)
  }

  function handleAmount1Change(value: string) {
    setAmount1Input(value)
    setActiveStepKind(undefined)
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
            disabled={buttonBusy}
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
            disabled={buttonBusy}
            aria-invalid={Boolean(amount1State.error || balanceError?.includes(token1Label))}
            onChange={(event) => handleAmount1Change(event.target.value)}
          />
        </label>
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
          ) : depositConfirmed ? (
            <CheckCircle size={17} weight="bold" />
          ) : (
            <Coins size={17} weight="bold" />
          )}
          {buttonLabel(activeStepKind, isPending, isConfirming)}
        </button>
      )}

      {formError ? <p className="form-message form-error deposit-status">{formError}</p> : null}
      {depositConfirmed ? <p className="form-message form-success deposit-status">Deposit complete.</p> : null}
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

function buildDepositSteps({
  amount0,
  amount1,
  needsToken0Approval,
  needsToken1Approval,
  token0Address,
  token1Address,
}: {
  amount0: bigint
  amount1: bigint
  needsToken0Approval: boolean
  needsToken1Approval: boolean
  token0Address: Address
  token1Address: Address
}) {
  const steps: DepositStep[] = []

  if (needsToken0Approval) {
    steps.push({
      kind: 'approve0',
      tokenAddress: token0Address,
      amount: amount0,
    })
  }

  if (needsToken1Approval) {
    steps.push({
      kind: 'approve1',
      tokenAddress: token1Address,
      amount: amount1,
    })
  }

  steps.push({
    kind: 'deposit',
    amount0,
    amount1,
  })

  return steps
}

function buttonLabel(stepKind: DepositStep['kind'] | undefined, isPending: boolean, isConfirming: boolean) {
  if (!stepKind) {
    return 'Deposit'
  }

  if (isConfirming) {
    return stepKind === 'deposit' ? 'Confirming deposit' : 'Confirming approval'
  }

  if (isPending) {
    return stepKind === 'deposit' ? 'Depositing' : 'Preparing deposit'
  }

  return 'Deposit'
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
