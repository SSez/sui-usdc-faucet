import { useMemo } from 'react';
import { useAppStore } from './store.ts';

function shortDigest(d: string) {
  return d.length > 12 ? `${d.slice(0, 8)}…${d.slice(-6)}` : d;
}

function isHexAddress(s: string) {
  return /^0x[0-9a-fA-F]{2,}$/.test(s);
}

export default function App() {
  const {
    amount,
    recipient,
    busy,
    txDigest,
    error,
    lastSent,
    setField,
    setRecipient,
    requestUSDC
  } = useAppStore();

  const canRequest = useMemo(
    () => !!(recipient && Number(amount) > 0),
    [recipient, amount]
  );

  return (
    <div className="min-h-screen bg-gray-50 text-gray-900 dark:bg-gray-900 dark:text-gray-100">
      <div className="mx-auto max-w-3xl px-4 py-8">
        <div className="mb-6 flex items-center justify-between">
          <h1 className="text-2xl font-semibold">Sui USDC Faucet</h1>
          <div className="text-sm text-gray-500">Network: Devnet</div>
        </div>

        <div className="grid gap-4">
          <section className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm dark:border-gray-800 dark:bg-gray-800">
            <h2 className="mb-3 text-lg font-medium">Request USDC</h2>
            <div className="grid gap-3 md:grid-cols-3">
              <div>
                <label className="mb-1 block text-sm">Recipient Address</label>
                <input
                  className="w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm dark:border-gray-700 dark:bg-gray-900"
                  value={recipient}
                  onChange={(e) => setRecipient(e.target.value)}
                  placeholder="0x...recipient"
                />
              </div>
              <div>
                <label className="mb-1 block text-sm">Amount (USDC)</label>
                <input
                  className="w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm dark:border-gray-700 dark:bg-gray-900"
                  value={amount}
                  onChange={(e) => setField('amount', e.target.value)}
                  placeholder="100"
                />
              </div>
              <div className="flex items-end">
                <button
                  className="inline-flex items-center justify-center gap-2 rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-60 w-full"
                  disabled={!canRequest || busy || !isHexAddress(recipient)}
                  onClick={requestUSDC}
                >
                  {busy ? 'Requesting…' : 'Request USDC'}
                </button>
              </div>
            </div>
            {txDigest && lastSent && (
              <div className="mt-4 rounded-md border border-green-300 bg-green-50 p-3 text-sm text-green-900 dark:border-green-700/40 dark:bg-green-900/30 dark:text-green-200">
                <div className="font-medium">Success</div>
                <div>
                  Sent{' '}
                  <strong>
                    {lastSent.amount.toLocaleString(undefined, {
                      maximumFractionDigits: 6
                    })}
                  </strong>{' '}
                  USDC to
                  <span className="ml-1 font-mono">
                    {recipient.slice(0, 8)}…{recipient.slice(-6)}
                  </span>
                </div>
                <div>
                  Tx:{' '}
                  <a
                    className="underline"
                    href={`https://suiexplorer.com/txblock/${txDigest}?network=devnet`}
                    target="_blank"
                    rel="noreferrer"
                  >
                    {shortDigest(txDigest)}
                  </a>
                </div>
              </div>
            )}
            {error && (
              <div className="mt-4 rounded-md border border-red-300 bg-red-50 p-3 text-sm text-red-900 dark:border-red-700/40 dark:bg-red-900/30 dark:text-red-200">
                <div className="font-medium">Error</div>
                <div>{error}</div>
              </div>
            )}
          </section>
        </div>
      </div>
    </div>
  );
}
