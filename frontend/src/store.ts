import { create } from 'zustand';

type AppState = {
  amount: string; // in human USDC, e.g., "100"
  setField: (key: keyof Pick<AppState, 'amount'>, value: any) => void;
};

export const useAppStore = create<AppState>((set) => ({
  amount: '100',
  setField: (key, value) => set({ [key]: value } as any),
}));
