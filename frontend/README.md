# Frontend (Server-Signed Faucet UI)

This React + Vite + Tailwind web app lets users request USDC by typing a recipient address and amount. It talks to the backend server, which signs and submits the on-chain transaction.

## Requirements

- Node 20+
- Backend server running (see `../backend/README.md`)

## Run

```bash
npm install
npm run dev
# Open http://localhost:3000
```

## Configuration

Edit `src/config.ts` to set your devnet IDs:

- `networkConfig["sui:devnet"].faucetPackage` — your faucet package (from `publish.out.json`)
- `networkConfig["sui:devnet"].faucetId` — your Faucet object (from `init.out.json`)
- `clockId` defaults to `0x6` in the UI

The app is config-driven. No wallet required. The backend must be configured with the same faucet values.

## Usage

1. Type a recipient address (0x...)
2. Enter an amount in whole USDC (UI converts to 6 decimals)
3. Click “Request USDC”
4. The backend returns a transaction digest if successful

## Build

The Vite config outputs the production build to `../backend/templates/dist` for easy hosting from the backend.

```bash
npm run build
```

## Customize

- Styles: Tailwind v4 (`src/index.css`)
- State: minimal Zustand store (`src/store.ts`)
- API URL: hardcoded to `http://localhost:8787/api/request` in `src/App.tsx` — change for deployment