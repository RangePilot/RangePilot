import { useState } from 'react'
import { CircleNotch, SignOut, Wallet } from '@phosphor-icons/react'
import type { Address } from 'viem'
import { formatAddress } from '../utils/format'
import type { BrowserConnector } from '../utils/connectors'
import { NetworkSwitcher } from './NetworkSwitcher'

export function AppHeader({
  address,
  browserConnectors,
  isConnected,
  isConnectPending,
  isSwitchPending,
  selectedChainId,
  onConnect,
  onDisconnect,
  onSelectChain,
}: {
  address?: Address
  browserConnectors: readonly BrowserConnector[]
  isConnected: boolean
  isConnectPending: boolean
  isSwitchPending: boolean
  selectedChainId: number
  onConnect: (connector?: BrowserConnector) => void
  onDisconnect: () => void
  onSelectChain: (chainId: number) => void
}) {
  const [isWalletMenuOpen, setIsWalletMenuOpen] = useState(false)

  function handleConnect(connector?: BrowserConnector) {
    setIsWalletMenuOpen(false)
    onConnect(connector)
  }

  return (
    <header className="topbar" aria-label="RangePilot console header">
      <div className="brand-lockup">
        <div className="brand-mark" aria-hidden="true">
          <img src="/rangepilot-icon-light.png" alt="" />
        </div>
        <div>
          <h1>RangePilot</h1>
        </div>
      </div>

      <div className="topbar-actions">
        <NetworkSwitcher
          selectedChainId={selectedChainId}
          onSelectChain={onSelectChain}
          isSwitchPending={isSwitchPending}
        />
        {isConnected ? (
          <button type="button" className="button button-secondary" onClick={onDisconnect}>
            <SignOut size={18} weight="bold" />
            {formatAddress(address)}
          </button>
        ) : (
          <div className="wallet-picker">
            <button
              type="button"
              className="button button-primary"
              disabled={browserConnectors.length === 0 || isConnectPending}
              onClick={() => {
                if (browserConnectors.length <= 1) {
                  handleConnect(browserConnectors[0])
                  return
                }
                setIsWalletMenuOpen((current) => !current)
              }}
            >
              {isConnectPending ? <CircleNotch className="spin" size={18} /> : <Wallet size={18} weight="bold" />}
              Connect Wallet
            </button>
            {isWalletMenuOpen ? (
              <div className="wallet-menu" role="menu" aria-label="Available browser wallets">
                <p className="wallet-menu-title">Browser wallets</p>
                {browserConnectors.map((connector) => (
                  <button
                    key={connector.uid}
                    type="button"
                    className="wallet-option"
                    role="menuitem"
                    disabled={isConnectPending}
                    onClick={() => handleConnect(connector)}
                  >
                    {connector.icon ? <img src={connector.icon} alt="" /> : <Wallet size={18} weight="bold" />}
                    <span>{connector.name}</span>
                  </button>
                ))}
              </div>
            ) : null}
          </div>
        )}
      </div>
    </header>
  )
}
