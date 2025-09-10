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

The frontend calls the backend at `API_BASE`.

- Configure via Vite env: `VITE_API_BASE=http://localhost:8787`
- Or edit `src/config.ts` (default is `http://localhost:8787`).

The backend must be configured with your on-chain faucet values (see backend README).

## Usage

1. Type a recipient address (0x...)
2. Enter an amount in whole USDC (UI converts to 6 decimals)
3. Click “Request USDC”
4. On success, you will see a message like: “Success — Sent X USDC … Tx: <digest>” with a link to Sui Explorer
5. Errors are displayed with a descriptive message returned by the backend

## Build

The Vite config outputs the production build to `../backend/templates/dist` for easy hosting from the backend.

```bash
npm run build
```

## Customize

- Styles: Tailwind v4 (`src/index.css`)
- State: minimal Zustand store (`src/store.ts`)
- API URL: `src/config.ts` (`API_BASE`)