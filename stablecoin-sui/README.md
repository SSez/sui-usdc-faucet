# stablecoin-sui

## Devnet/Testnet Faucet (USDC) — This fork

This fork adds a simple faucet module under `packages/stablecoin/sources/faucet.move` that is intended for devnet/testnet only. It is generic over the coin type `T` and integrates with `stablecoin::treasury::Treasury<T>` (which wraps `0x2::coin::TreasuryCap<T>`). On devnet/testnet it uses a devnet-only mint path.

The flow below shows USDC on devnet; adapt as needed for testnet.

### 1) Build & Publish Dependencies (in order)

#### 1a) Publish sui_extensions
```bash
cd packages/sui_extensions
sui move build
mkdir ../../json
sui client publish --gas-budget 300000000 --json | tee ../../json/sui_extensions.out.json

export SUI_EXTENSIONS_PACKAGE=$(jq -r '.objectChanges[] | select(.type=="published") | .packageId' ../../json/sui_extensions.out.json)
echo "SUI_EXTENSIONS_PACKAGE=$SUI_EXTENSIONS_PACKAGE"
```

#### 1b) Publish stablecoin
```bash
cd ../stablecoin
sui move build
sui client publish --gas-budget 300000000 --with-unpublished-dependencies --json | tee ../../json/stablecoin.out.json

export STABLECOIN_PACKAGE=$(jq -r '.objectChanges[] | select(.type=="published") | .packageId' ../../json/stablecoin.out.json)
echo "STABLECOIN_PACKAGE=$STABLECOIN_PACKAGE"
```

#### 1c) Publish USDC (packages/usdc)

```bash
cd ../usdc
sui move build
sui client publish --gas-budget 300000000 --with-unpublished-dependencies --json | tee ../../json/usdc.out.json

export USDC_PACKAGE=$(jq -r '.objectChanges[] | select(.type=="published") | .packageId' ../../json/usdc.out.json)
export TREASURY=$(jq -r '.objectChanges[] | select(.type=="created" and (.objectType|test("::treasury::Treasury<.*::usdc::USDC>"))) | .objectId' ../../json/usdc.out.json)
echo "USDC_PACKAGE=$USDC_PACKAGE" && echo "TREASURY=$TREASURY"
```

Print USDC Contract Address
```bash
echo "$USDC_PACKAGE::usdc::USDC"
```

### 2) Verify Treasury Object ID

The Treasury object ID should have been extracted from the USDC publication JSON. If not found, you can locate it:

```bash
# If TREASURY is not set, find it from the objects
if [ -z "$TREASURY" ]; then
  echo "Finding Treasury object..."
  # Look for Treasury objects with your USDC package type
  sui client objects | grep -A5 -B5 "::treasury::Treasury<.*::usdc::USDC>"
  # Manually set the Treasury object ID if found
  export TREASURY=<FOUND_TREASURY_OBJECT_ID>
fi
echo "TREASURY=$TREASURY"
```

### 3) Verify STABLECOIN_PACKAGE

The stablecoin package should have been extracted from the stablecoin publication JSON. You can also derive it from the Treasury:

```bash
# If STABLECOIN_PACKAGE is not set, derive it from Treasury
if [ -z "$STABLECOIN_PACKAGE" ]; then
  echo "Deriving STABLECOIN_PACKAGE from Treasury..."
  export STABLECOIN_PACKAGE=$(sui client object "$TREASURY" --json | jq -r '(.data.type // .type) | split("::")[0]')
fi
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
  --json | tee ../../json/faucet.out.json

export FAUCET_ID=$(jq -r '.objectChanges[] | select(.type=="created" and (.objectType|test("::faucet::Faucet<.*::usdc::USDC>"))) | .objectId' ../../json/faucet.out.json)
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
  --args "$FAUCET_ID" "$FAUCET_ID" 50000000 "$CLOCK" \
  --gas-budget 10000000

# Or mint to a specific recipient
sui client call \
  --package "$STABLECOIN_PACKAGE" \
  --module faucet \
  --function request \
  --type-args "$USDC_PACKAGE::usdc::USDC" \
  --args "$FAUCET_ID" <RECIPIENT_ADDRESS> 50000000 "$CLOCK" \
  --gas-budget 10000000
```

## Environment Configuration

For the backend faucet service, update your `.env` file with these values extracted from the JSON files:

```bash
# Extract values from JSON files
STABLECOIN_PACKAGE=$(jq -r '.objectChanges[] | select(.type=="published") | .packageId' ../../json/stablecoin.out.json)
USDC_PACKAGE=$(jq -r '.objectChanges[] | select(.type=="published") | .packageId' ../../json/usdc.out.json)
TREASURY=$(jq -r '.objectChanges[] | select(.type=="created" and (.objectType|test("::treasury::Treasury<.*::usdc::USDC>"))) | .objectId' ../../json/usdc.out.json)
FAUCET_ID=$(jq -r '.objectChanges[] | select(.type=="created" and (.objectType|test("::faucet::Faucet<.*::usdc::USDC>"))) | .objectId' ../../json/faucet.out.json)

# backend/.env file content:
cat > backend/.env << EOF
PORT=8787
FULLNODE_URL=https://fullnode.devnet.sui.io:443
CLOCK=0x6
FAUCET_ID=$FAUCET_ID

# Stablecoin faucet (generic over USDC)
STABLECOIN_PACKAGE=$STABLECOIN_PACKAGE
USDC_PACKAGE=$USDC_PACKAGE
TREASURY=$TREASURY
EOF
```

## Frontend Configuration

Update your frontend config to use the local USDC by extracting the values:

```bash
# Extract protocol package ID (assuming you published aquilo_protocol)
AQUILO_PACKAGE=$(jq -r '.objectChanges[] | select(.type=="published") | .packageId' ../../json/aquilo_protocol.out.json)

# Extract market factory ID from protocol publication
MARKET_FACTORY_ID=$(jq -r '.objectChanges[] | select(.type=="created" and (.objectType|test("::market_factory::MarketFactory"))) | .objectId' ../../json/aquilo_protocol.out.json)

echo "Frontend config values:"
echo "packageId: $AQUILO_PACKAGE"
echo "marketFactoryId: $MARKET_FACTORY_ID"
echo "usdc: $USDC_PACKAGE::usdc::USDC"

# Update frontend/src/config.ts with these values
```

Example config.ts content:
```typescript
// config.ts
export const networkConfig: Record<string, NetworkConfig> = {
  'sui:devnet': {
    packageId: '$AQUILO_PACKAGE',
    marketFactoryId: '$MARKET_FACTORY_ID',
    usdc: '$USDC_PACKAGE::usdc::USDC'
  },
  // ... other networks
};
```

## Summary

✅ **TypeMismatch Resolved**: All components now use the same USDC type from your published local packages.

🔄 **Next Steps**:
1. Find the Treasury object ID created during USDC initialization
2. Create the faucet using the Treasury
3. Test minting USDC tokens
4. Update your backend `.env` file with the correct values

Restart backend and POST to `/api/request` with `recipient` and `amount` (atomic units).

> Note: This faucet and the devnet mint path are for devnet/testnet only. Do not use on mainnet.
