import { useMemo, useState } from 'react';
import { useAppStore } from './store.ts';
import { API_BASE } from './config';

export default function App() {
  const { amount, setField } = useAppStore();

  const [recipient, setRecipient] = useState<string>('');
  const canRequest = useMemo(
    () => !!(recipient && Number(amount) > 0),
    [recipient, amount]
  );

  const [busy, setBusy] = useState(false);
  const [txDigest, setTxDigest] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function onRequest() {
    setBusy(true);
    setTxDigest(null);
    setError(null);
    try {
      const amt = Math.floor(Number(amount) * 1_000_000);
      const res = await fetch(`${API_BASE}/api/request`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ recipient, amount: amt })
      });
      if (!res.ok) {
        const msg = await res.text();
        throw new Error(msg || `Request failed with ${res.status}`);
      }
      const data = await res.json();
      setTxDigest(data.digest || data.txDigest || null);
    } catch (err: any) {
      setError(err?.message ?? String(err));
    } finally {
      setBusy(false);
    }
  }

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
                  disabled={!canRequest || busy}
                  onClick={onRequest}
                >
                  {busy ? 'Requesting…' : 'Request USDC'}
                </button>
              </div>
            </div>
            {txDigest && (
              <p className="mt-3 text-sm text-green-600">
                Success! Tx: {txDigest}
              </p>
            )}
            {error && (
              <p className="mt-3 text-sm text-red-600">Error: {error}</p>
            )}
          </section>
        </div>
      </div>
    </div>
  );
}
