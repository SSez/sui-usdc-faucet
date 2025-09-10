# stablecoin-sui

Source repository for smart contracts used by Circle's stablecoins on Sui blockchain

## Getting Started

### Prerequisites

Before you can start working with the contracts in this repository, make sure to set up your local environment using the script below.

```bash
bash setup.sh
```

### IDE

- VSCode is recommended for developing Move contracts.
- [Move (Extension)](https://marketplace.visualstudio.com/items?itemName=mysten.move) is a language server extension for Move.

### Build and Test Move contracts

1. Compile Move contracts from project root:

   ```bash
   bash run.sh build
   ```

2. Run the tests:

   ```bash
   bash run.sh test
   ```

### Deploying Move packages

#### Deploying with Sui CLI

Packages in this repo can be published [via the Sui CLI](https://docs.sui.io/guides/developer/first-app/publish).

## Devnet/Testnet Faucet (USDC) — This fork

This fork adds a simple faucet module under `packages/stablecoin/sources/faucet.move` that is intended for devnet/testnet only. It is generic over the coin type `T` and integrates with `stablecoin::treasury::Treasury<T>` (which wraps `0x2::coin::TreasuryCap<T>`). On devnet/testnet it uses a devnet-only mint path.

The flow below shows USDC on devnet; adapt as needed for testnet.

### 1) Build

```bash
# From repo root (this folder):
bash run.sh build
```

### 2) Publish USDC (packages/usdc)

```bash
cd packages/usdc
sui client publish --gas-budget 300000000 --with-unpublished-dependencies --json | tee usdc.out.json

export USDC_PACKAGE=$(jq -r '.objectChanges[] | select(.type=="published") | .packageId' usdc.out.json)
export TREASURY=$(jq -r '.objectChanges[] | select(.type=="created" and (.objectType|test("::treasury::Treasury<.*::usdc::USDC>"))) | .objectId' usdc.out.json)
echo "USDC_PACKAGE=$USDC_PACKAGE" && echo "TREASURY=$TREASURY"
```
Important: Do NOT transfer the TreasuryCap<USDC> out of the Treasury. The faucet requires the TreasuryCap to remain inside the `Treasury<USDC>` object.

### 3) Derive STABLECOIN_PACKAGE from your Treasury (types must match)

```bash
# Use the package address embedded in the Treasury's type
export STABLECOIN_PACKAGE=$(sui client object "$TREASURY" --json | jq -r '(.data.type // .type) | split("::")[0]')
echo "STABLECOIN_PACKAGE=$STABLECOIN_PACKAGE"
```

### 4) Create the Faucet for T = USDC

The faucet is a shared object bound to a `Treasury<T>`.

```bash
export CLOCK=0x6

# Create a shared Faucet<USDC>
sui client call \
  --package "$STABLECOIN_PACKAGE" \
  --module faucet \
  --function create \
  --type-args "$USDC_PACKAGE::usdc::USDC" \
  --args "$TREASURY" \
  --gas-budget 10000000 \
  --json | tee faucet.create.out.json

export FAUCET_ID=$(jq -r '.objectChanges[] | select(.type=="created" and (.objectType|test("::faucet::Faucet<.*::usdc::USDC>"))) | .objectId' faucet.create.out.json)
echo "FAUCET_ID=$FAUCET_ID"
```

### 5) Request tokens (sender or specific recipient)

Amounts are in atomic units (USDC has 6 decimals). For 50 USDC, use `50000000`.

```bash
# Sender mints to self
sui client call \
  --package "$STABLECOIN_PACKAGE" \
  --module faucet \
  --function request \
  --type-args "$USDC_PACKAGE::usdc::USDC" \
  --args "$FAUCET_ID" "$TREASURY" 50000000 "$CLOCK" \
  --gas-budget 10000000

# Mint to specific recipient
sui client call \
  --package "$STABLECOIN_PACKAGE" \
  --module faucet \
  --function request_for \
  --type-args "$USDC_PACKAGE::usdc::USDC" \
  --args "$FAUCET_ID" "$TREASURY" 0xRECIPIENT 50000000 "$CLOCK" \
  --gas-budget 10000000
```

### 6) Backend wiring (optional)

The repo’s backend supports this stablecoin faucet mode. Set the following in `backend/.env`:

```
FULLNODE_URL=https://fullnode.devnet.sui.io:443
CLOCK=0x6
FAUCET_ID=0x...            # From faucet.create.out.json
STABLECOIN_PACKAGE=0x...   # Derived from the Treasury type (see step 3)
USDC_PACKAGE=0x...         # From usdc.out.json (same as STABLECOIN_PACKAGE if published with --with-unpublished-dependencies)
TREASURY=0x...             # Treasury<USDC> object id
SUI_PRIVATE_KEY=suiprivkey1... | ed25519:<base64> | 0x<hex>
```

Restart backend and POST to `/api/request` with `recipient` and `amount` (atomic units).

> Note: This faucet and the devnet mint path are for devnet/testnet only. Do not use on mainnet.
