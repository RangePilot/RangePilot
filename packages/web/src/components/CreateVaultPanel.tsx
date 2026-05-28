import { useEffect, useRef, useState, type FormEvent } from 'react'
import { CircleNotch, Stack } from '@phosphor-icons/react'
import { isAddress, type Address, type Hash } from 'viem'
import { useWaitForTransactionReceipt, useWriteContract } from 'wagmi'
import type { DeploymentConfig } from '../config/contracts'
import { vaultFactoryAbi } from '../contracts/abis'
import { explorerTransaction } from '../utils/explorer'
import { formatPoolId } from '../utils/format'

export function CreateVaultPanel({
  owner,
  deployment,
  chainId,
  chainName,
  isWalletOnSelectedChain,
  isSwitchPending,
  onSwitchChain,
  onVaultCreated,
}: {
  owner?: Address
  deployment: DeploymentConfig
  chainId: number
  chainName: string
  isWalletOnSelectedChain: boolean
  isSwitchPending: boolean
  onSwitchChain: () => void
  onVaultCreated: () => void | Promise<unknown>
}) {
  const [aiOperatorInput, setAiOperatorInput] = useState('')
  const [hasSubmitted, setHasSubmitted] = useState(false)
  const handledHash = useRef<Hash | undefined>(undefined)
  const aiOperatorValue = aiOperatorInput.trim()
  const aiOperator = isAddress(aiOperatorValue) ? (aiOperatorValue as Address) : undefined
  const inputError = aiOperatorValue && !aiOperator ? 'Enter a valid EVM address.' : undefined
  const { data: hash, error: writeError, isPending, writeContract } = useWriteContract()
  const {
    isLoading: isConfirming,
    isSuccess: isConfirmed,
    error: receiptError,
  } = useWaitForTransactionReceipt({
    hash,
    chainId,
  })
  const canCreate = Boolean(
    owner &&
      deployment.vaultFactory &&
      aiOperator &&
      isWalletOnSelectedChain &&
      !isPending &&
      !isConfirming,
  )

  useEffect(() => {
    if (isConfirmed && hash && handledHash.current !== hash) {
      handledHash.current = hash
      void onVaultCreated()
    }
  }, [hash, isConfirmed, onVaultCreated])

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setHasSubmitted(true)

    if (!canCreate || !owner || !deployment.vaultFactory || !aiOperator) {
      return
    }

    writeContract({
      address: deployment.vaultFactory,
      abi: vaultFactoryAbi,
      functionName: 'createVault',
      args: [owner, aiOperator],
      chainId,
    })
  }

  return (
    <section className="panel create-vault-panel">
      <div className="panel-heading">
        <div>
          <h2>Create a Vault</h2>
        </div>
        <span className="network-chip">{chainName}</span>
      </div>

      <form className="vault-form" onSubmit={handleSubmit}>
        <label htmlFor="ai-operator">AI Operator</label>
        <div className="input-row">
          <input
            id="ai-operator"
            type="text"
            value={aiOperatorInput}
            spellCheck={false}
            autoComplete="off"
            placeholder="Your OnchainOS EVM Address (Prompt AI: Tell me my evm address or Using command 'onchainos wallet address')"
            aria-invalid={Boolean(inputError || (hasSubmitted && !aiOperator))}
            onChange={(event) => setAiOperatorInput(event.target.value)}
          />
        </div>
        {inputError || (hasSubmitted && !aiOperator) ? (
          <p className="form-message form-error">{inputError ?? 'AI Operator is required.'}</p>
        ) : null}
        {!deployment.vaultFactory ? (
          <p className="form-message form-error">VaultFactory is not configured for this network.</p>
        ) : null}
        {!isWalletOnSelectedChain ? (
          <button
            type="button"
            className="button button-secondary form-switch"
            disabled={isSwitchPending}
            onClick={onSwitchChain}
          >
            Switch network
          </button>
        ) : (
          <button type="submit" className="button button-primary form-submit" disabled={!canCreate}>
            {isPending || isConfirming ? <CircleNotch className="spin" size={18} /> : <Stack size={18} weight="bold" />}
            {isConfirming ? 'Confirming' : isPending ? 'Creating' : 'Create Vault'}
          </button>
        )}
        {hash ? (
          <a className="text-link tx-link" href={explorerTransaction(chainId, hash)} target="_blank" rel="noreferrer">
            {formatPoolId(hash)}
          </a>
        ) : null}
        {isConfirmed ? <p className="form-message form-success">Vault created.</p> : null}
        {writeError || receiptError ? (
          <p className="form-message form-error">{(writeError ?? receiptError)?.message}</p>
        ) : null}
      </form>
    </section>
  )
}
