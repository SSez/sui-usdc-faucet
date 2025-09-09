# Backend (Server-Signed Faucet)

Express server that signs and submits Sui transactions to mint USDC via your Faucet smart contract. It calls `faucet::request_tokens_for(faucet, recipient, amount, clock)` on devnet.

## Requirements

- Node 20+
- A funded Sui account (this key pays gas)
- On-chain faucet deployed and initialized (see `../sui/README.md`)

## Environment

Create `.env` in this folder (see `.env.example`):

```
PORT=8787
FULLNODE_URL=https://fullnode.devnet.sui.io:443
FAUCET_PACKAGE=<packageId from publish.out.json>
FAUCET_ID=<objectId from init.out.json>
CLOCK=0x6
SUI_PRIVATE_KEY=0x<ed25519 secret hex>
```

Populate FAUCET_PACKAGE and FAUCET_ID from your JSON outputs:

```bash
# From your faucet publish (ran in repo root):
export FAUCET_PACKAGE=$(jq -r '.objectChanges[] | select(.type=="published") | .packageId' publish.out.json)

# From your faucet init:
export FAUCET_ID=$(jq -r '.objectChanges[] | select(.type=="created" and (.objectType|endswith("::faucet::Faucet"))) | .objectId' init.out.json)

echo "FAUCET_PACKAGE=$FAUCET_PACKAGE"
echo "FAUCET_ID=$FAUCET_ID"
```

Then paste those values into `.env` accordingly.

About `SUI_PRIVATE_KEY`:
- Hex-encoded Ed25519 secret (32 or 64 bytes in hex). Do NOT commit this file.
- The corresponding address must have devnet SUI for gas.

## Install & Run (dev)

```bash
npm install
npm run dev
# Backend listening on http://localhost:8787
```

## API

POST /api/request

Request body (JSON):
```
{
  "recipient": "0x...",          // Address to receive USDC
  "amount": 100000000              // u64 in 6 decimals (e.g., 100 USDC)
}
```

Response (JSON):
```
{ "digest": "..." }
```

Errors return HTTP 4xx/5xx with a message body.

## Security Notes

- Protect `SUI_PRIVATE_KEY` with proper secrets management.
- Add rate limiting and auth before public deployment.
- Restrict CORS and allowed origins.
# Backend (Server-Signed Faucet)

Express server that signs and submits Sui transactions to mint USDC via your Faucet.

## Requirements
- Node 20+
- Funded Sui account whose private key is set in env (pays gas)

## Installation & Run
```bash
npm install
# Copy env template and fill values
cp .env.example .env
npm run dev
# Server at http://localhost:8787