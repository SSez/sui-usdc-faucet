# Sui USDC Faucet — Full Stack (Server-Signed)

This repository lets you deploy your own USDC (Circle reference), publish a Faucet smart contract on Sui devnet, and run a simple web app where users can request test USDC by typing their address — no wallet or CLI required in the browser. The backend holds a signer key and submits transactions on behalf of users.

## Repository Structure

- `sui/` — Move package for the Faucet. Adds `request_tokens_for(recipient, amount, clock)` for server-signed requests.
- `backend/` — Express server that signs `request_tokens_for` and submits to Sui.
- `frontend/` — Vite + React + Tailwind app that collects recipient and amount, then calls the backend.

Each subfolder has its own README with setup details.

## Quickstart (Devnet)

1) Prerequisites

- Sui CLI, Node 20+, npm, jq
- Fund your devnet address: `sui client switch --env devnet && sui client faucet`

2) On-chain setup (USDC + Faucet)

- Follow the detailed steps in `sui/README.md` to:
  - Publish USDC (Circle reference) on devnet and obtain an AddressOwner `TreasuryCap<USDC>`
  - Build, publish (or re-publish) this Faucet package
  - Initialize the Faucet with your `TreasuryCap<USDC>`

You will end with two IDs needed by the backend:

- `FAUCET_PACKAGE` — from `publish.out.json` where `.objectChanges[].type == "published"` → `.packageId`
- `FAUCET_ID` — from `init.out.json` where `.objectChanges[].type == "created"` and `.objectType` ends with `::faucet::Faucet` → `.objectId`

3) Backend (server-signed)

- See `backend/README.md`. Create `backend/.env`:
  - `PORT=8787`
  - `FULLNODE_URL=https://fullnode.devnet.sui.io:443`
  - `FAUCET_PACKAGE=<packageId from publish.out.json>`
  - `FAUCET_ID=<objectId from init.out.json>`
  - `CLOCK=0x6`
  - `SUI_PRIVATE_KEY=0x<ed25519 secret hex>` (the server signer; must have SUI for gas)
- Start: `npm install && npm run dev` (in `backend/`).

4) Frontend

- See `frontend/README.md`.
- Start: `npm install && npm run dev` (in `frontend/`).
- Open http://localhost:3000, enter recipient and amount, click Request.

## Notes

- Do not use the public devnet USDC package to initialize your faucet — you won’t own its `TreasuryCap<USDC>`.
- Initialize with an AddressOwner `TreasuryCap<USDC>` only.
- The backend signer pays gas. Secure keys and rate-limit the endpoint before public use.

## READMEs

- `frontend/README.md` — How to run and customize the web app
- `backend/README.md` — Environment, keys, and API usage
- `sui/README.md` — Smart contract details and CLI snippets