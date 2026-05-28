import { supportedChains } from '../config/chains'

export function NetworkSwitcher({
  selectedChainId,
  onSelectChain,
  isSwitchPending,
}: {
  selectedChainId: number
  onSelectChain: (chainId: number) => void
  isSwitchPending: boolean
}) {
  return (
    <div className="segmented-control" role="tablist" aria-label="Select X Layer network">
      {supportedChains.map((chain) => (
        <button
          key={chain.id}
          type="button"
          role="tab"
          aria-selected={selectedChainId === chain.id}
          className={selectedChainId === chain.id ? 'active' : ''}
          disabled={isSwitchPending && selectedChainId === chain.id}
          onClick={() => onSelectChain(chain.id)}
        >
          {chain.testnet ? 'Testnet' : 'X Layer'}
        </button>
      ))}
    </div>
  )
}
