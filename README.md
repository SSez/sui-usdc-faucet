# Sui USDC Unofficial Faucet — Full Stack

This repository lets you deploy your own USDC (Circle reference), publish a Faucet smart contract on Sui devnet, and run a simple web app where users can request test USDC by typing their address — no wallet or CLI required in the browser. The backend holds a signer key and submits transactions on behalf of users.

## Repository Structure

- `sui/stablecoin-sui/` — Circle stablecoin reference with a generic `faucet` module under `packages/stablecoin/sources/faucet.move`.
- `backend/` — Express server that signs `request_tokens_for` and submits to Sui.
- `frontend/` — Vite + React + Tailwind app that collects recipient and amount, then calls the backend.

Each subfolder has its own README with setup details.

## Quickstart (Devnet)

1) Prerequisites

- Sui CLI, Node 20+, npm, jq
- Fund your devnet address: `sui client switch --env devnet && sui client faucet`

2) On-chain setup (USDC + Faucet)

- Follow the detailed steps in `sui/stablecoin-sui/README.md` to:
  - Publish USDC (Circle reference) on devnet with `--with-unpublished-dependencies`
  - Capture `USDC_PACKAGE` and `TREASURY`
  - Derive `STABLECOIN_PACKAGE` from the `TREASURY` type (guarantees matching addresses)
  - Create `Faucet<USDC>` using `stablecoin::faucet::create<T>`

You will end with the IDs needed by the backend:

- `STABLECOIN_PACKAGE` — derived from `TREASURY` type
- `USDC_PACKAGE` — from `usdc.out.json` (same as `STABLECOIN_PACKAGE` when published with `--with-unpublished-dependencies`)
- `TREASURY` — `stablecoin::treasury::Treasury<USDC>` object id
- `FAUCET_ID` — created `stablecoin::faucet::Faucet<USDC>` object id

3) Backend

- See `backend/README.md`. Create `backend/.env`:
  - `PORT=8787`
  - `FULLNODE_URL=https://fullnode.devnet.sui.io:443`
  - `CLOCK=0x6`
  - `FAUCET_ID=<objectId from faucet.create.out.json>`
  - `STABLECOIN_PACKAGE=<derived from Treasury type>`
  - `USDC_PACKAGE=<from usdc.out.json>`
  - `TREASURY=<stablecoin::treasury::Treasury<USDC> object id>`
  - `CLOCK=0x6`
  - `SUI_PRIVATE_KEY=suiprivkey1... | ed25519:<base64> | 0xHEX` (server signer; must have SUI for gas)
- Start: `npm install && npm run dev` (in `backend/`).

4) Frontend

- See `frontend/README.md`.
- Start: `npm install && npm run dev` (in `frontend/`).
- Open http://localhost:3000, enter recipient and amount, click Request.

## Notes

- Do not transfer the `TreasuryCap<USDC>` out of the `Treasury<USDC>`; the faucet uses a devnet-only mint path that requires the cap to remain inside the treasury.
- The backend signer pays gas. Secure keys and rate-limit the endpoint before public use.

## READMEs

- `frontend/README.md` — How to run and customize the web app
- `backend/README.md` — Environment, API, and deployment notes
- `sui/stablecoin-sui/README.md` — End-to-end USDC + Faucet setup on devnet
- `backend/README.md` — Environment, keys, and API usage
- `sui/README.md` — Smart contract details and CLI snippets