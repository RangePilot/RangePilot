import { CircleNotch, LinkBreak, Stack, Wallet, WarningCircle } from '@phosphor-icons/react'
import { zeroAddress, type Address } from 'viem'
import type { DeploymentConfig } from '../config/contracts'
import type { PoolPortfolio, VaultPortfolio } from '../hooks/useVaultPortfolio'
import { explorerAddress } from '../utils/explorer'
import { formatAddress, formatPoolId, formatTokenAmount } from '../utils/format'

export function VaultPanel({
  address,
  deployment,
  chainId,
  isConnected,
  isLoading,
  error,
  vault,
}: {
  address?: Address
  deployment: DeploymentConfig
  chainId: number
  isConnected: boolean
  isLoading: boolean
  error: Error | null
  vault?: VaultPortfolio
}) {
  if (!isConnected) {
    return (
      <section className="panel empty-panel">
        <Wallet size={28} weight="bold" />
        <h2>Connect your wallet to inspect your Vault</h2>
        <p>The console reads your Vault, pool accounts, and position metadata through VaultFactory.</p>
      </section>
    )
  }

  if (!deployment.vaultFactory) {
    return (
      <section className="panel config-panel">
        <WarningCircle size={24} weight="bold" />
        <div>
          <h2>RangePilot addresses are missing for this network</h2>
          <p>Add the deployed and verified contract addresses to the matching environment variables.</p>
          <dl className="config-list">
            <div>
              <dt>VaultFactory</dt>
              <dd>{chainId === 196 ? 'XLAYER_VAULT_FACTORY' : 'XLAYER_TESTNET_VAULT_FACTORY'}</dd>
            </div>
            <div>
              <dt>ManagedLPHook</dt>
              <dd>
                {chainId === 196 ? 'XLAYER_MANAGED_LP_HOOK' : 'XLAYER_TESTNET_MANAGED_LP_HOOK'}
              </dd>
            </div>
          </dl>
        </div>
      </section>
    )
  }

  if (isLoading) {
    return (
      <section className="panel loading-panel">
        <CircleNotch className="spin" size={26} />
        <h2>Reading Vault</h2>
        <p>Loading Factory data, Vault metadata, and the pool list.</p>
      </section>
    )
  }

  if (error) {
    return (
      <section className="panel empty-panel">
        <LinkBreak size={28} weight="bold" />
        <h2>Read failed</h2>
        <p>{error.message}</p>
      </section>
    )
  }

  if (!vault?.vaultAddress) {
    return (
      <section className="panel empty-panel">
        <Stack size={28} weight="bold" />
        <h2>No Vault found for this address</h2>
        <p>{formatAddress(address)} does not have a Vault registered in this network's Factory.</p>
      </section>
    )
  }

  return (
    <section className="panel vault-panel">
      <div className="panel-heading">
        <div>
          <p className="eyebrow">Vault profile</p>
          <h2>{formatAddress(vault.vaultAddress, 6)}</h2>
        </div>
        <a className="text-link" href={explorerAddress(chainId, vault.vaultAddress)} target="_blank" rel="noreferrer">
          Explorer
        </a>
      </div>

      <dl className="detail-grid">
        <DetailItem label="Owner" value={formatAddress(vault.vaultOwner)} />
        <DetailItem label="AI Operator" value={vault.aiOperator === zeroAddress ? 'Not set' : formatAddress(vault.aiOperator)} />
      </dl>

      <div className="vault-pools">
        <div className="subheading-row">
          <h3>Attached pools</h3>
          <span className="muted">{vault.poolCount} total</span>
        </div>
        {vault.pools.length === 0 ? (
          <p className="muted">No pools are attached yet.</p>
        ) : (
          <div className="vault-pool-list">
            {vault.pools.map((pool) => (
              <VaultPoolItem key={pool.poolId} pool={pool} />
            ))}
          </div>
        )}
      </div>
    </section>
  )
}

function DetailItem({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt>{label}</dt>
      <dd>{value}</dd>
    </div>
  )
}

function VaultPoolItem({ pool }: { pool: PoolPortfolio }) {
  const token0 = pool.token0?.symbol ?? formatAddress(pool.key?.currency0)
  const token1 = pool.token1?.symbol ?? formatAddress(pool.key?.currency1)

  return (
    <div className="vault-pool-item">
      <div>
        <strong>
          {token0} / {token1}
        </strong>
        <span className="muted">{formatPoolId(pool.poolId)}</span>
      </div>
      <div>
        <span>
          {formatTokenAmount(pool.balance?.idle0, pool.token0?.decimals)} /{' '}
          {formatTokenAmount(pool.balance?.idle1, pool.token1?.decimals)}
        </span>
        <span className="muted">tick {pool.slot0?.tick ?? '-'}</span>
      </div>
    </div>
  )
}
