# Backend (Server-Signed Faucet)

Express server that signs and submits Sui transactions to mint USDC via your Faucet smart contract. It calls `stablecoin::faucet::request_for<T>` on devnet with `T = usdc::USDC`.

## Requirements

- Node 20+
- A funded Sui account (this key pays gas)
- On-chain faucet deployed and initialized (see `../sui/stablecoin-sui/README.md`)

## Environment

Create `.env` in this folder (see `.env.example`). Stablecoin-only mode (recommended):

```
PORT=8787
FULLNODE_URL=https://fullnode.devnet.sui.io:443
CLOCK=0x6
FAUCET_ID=<objectId from faucet.create.out.json>
STABLECOIN_PACKAGE=<derived from Treasury type>
USDC_PACKAGE=<from usdc.out.json>
TREASURY=<objectId of stablecoin::treasury::Treasury<USDC>>
# SUI private key (see below for formats)
SUI_PRIVATE_KEY=
```

About `SUI_PRIVATE_KEY`:
- Accepted formats:
  - `suiprivkey1...` (bech32)
  - `ed25519:<base64>` (Sui export)
  - hex: 32 or 64 bytes (with or without `0x`)
- Do NOT commit `.env`. The key’s address must have devnet SUI for gas.

## Install & Run (dev)

```bash
npm install
cp .env.example .env  # then fill values
npm run dev
# Backend listening on http://localhost:8787
```

## API

POST `/api/request`

Request body (JSON):
```json
{
  "recipient": "0x...",
  "amount": 100000000
}
```
- `recipient`: address to receive USDC
- `amount`: atomic units (USDC has 6 decimals); e.g. 100 USDC = 100_000_000

Response (JSON):
```json
{ "digest": "<transaction digest>" }
```

Errors return HTTP 4xx/5xx with a JSON `{ error: "..." }` or text message. The frontend parses both.

## Notes

- All on-chain objects and type-args must come from the same package addresses (see `../sui/stablecoin-sui/README.md`).
- Do not transfer the `TreasuryCap<USDC>` out of the `Treasury<USDC>`; the faucet’s devnet path requires the cap to remain inside the treasury.
- Add rate limiting and auth before public use. Restrict CORS to trusted origins.
- Funded Sui account whose private key is set in env (pays gas)

## Installation & Run
```bash
npm install
# Copy env template and fill values
cp .env.example .env
npm run dev
# Server at http://localhost:8787