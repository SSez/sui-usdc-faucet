import { create } from 'zustand';
import { API_BASE } from './config';

function parseErrorMessage(error: string): string {
  if (error.includes('MoveAbort') && error.includes('code 1')) {
    return 'Rate limit exceeded. You have reached the maximum number of requests allowed in the current period. Please wait before trying again.';
  }
  if (error.includes('TypeMismatch')) {
    return 'Configuration error: Package addresses do not match. Please check the backend configuration.';
  }
  if (error.includes('Dry run failed')) {
    return 'Transaction simulation failed. This may be due to rate limits or configuration issues.';
  }
  return error;
}

type AppState = {
  amount: string;
  recipient: string;
  busy: boolean;
  txDigest: string | null;
  error: string | null;
  lastSent: { recipient: string; amount: number } | null;
  setField: (key: keyof Pick<AppState, 'amount'>, value: any) => void;
  setRecipient: (recipient: string) => void;
  setBusy: (busy: boolean) => void;
  setTxDigest: (digest: string | null) => void;
  setError: (error: string | null) => void;
  setLastSent: (lastSent: { recipient: string; amount: number } | null) => void;
  requestUSDC: () => Promise<void>;
};

export const useAppStore = create<AppState>((set, get) => ({
  amount: '100',
  recipient: '',
  busy: false,
  txDigest: null,
  error: null,
  lastSent: null,
  setField: (key, value) => set({ [key]: value } as any),
  setRecipient: (recipient) => set({ recipient }),
  setBusy: (busy) => set({ busy }),
  setTxDigest: (digest) => set({ txDigest: digest }),
  setError: (error) => set({ error }),
  setLastSent: (lastSent) => set({ lastSent }),
  requestUSDC: async () => {
    const { recipient, amount, setBusy, setTxDigest, setError, setLastSent } =
      get();
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
        const ct = res.headers.get('content-type') || '';
        if (ct.includes('application/json')) {
          const j = await res.json();
          throw new Error(
            j?.error || j?.message || `Request failed with ${res.status}`
          );
        }
        const msg = await res.text();
        throw new Error(msg || `Request failed with ${res.status}`);
      }
      const data = await res.json();
      const digest = data.digest || data.txDigest || null;
      setTxDigest(digest);
      setLastSent({ recipient, amount: Number(amount) });
    } catch (err: any) {
      setError(parseErrorMessage(err?.message ?? String(err)));
    } finally {
      setBusy(false);
    }
  }
}));
