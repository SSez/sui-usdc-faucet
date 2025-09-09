# SUI USDC Faucet 

A Sui Move smart contract that provides a faucet for Circle's USDC stablecoin on Sui devnet.

## Overview

This faucet allows users to request USDC tokens with built-in rate limiting to prevent abuse. It integrates with Circle's regulated stablecoin implementation and provides a controlled way to distribute test USDC for development and testing purposes.

## Features

- **Rate Limiting**: Users can request up to 3 times per 24-hour period
- **Amount Limits**: Maximum 1,000,000 USDC per request (6 decimals = 1,000,000 × 1,000,000 units)
- **Request Tracking**: Tracks user requests and prevents abuse
- **Event Logging**: Emits events for all faucet requests
- **Owner Controls**: Faucet owner can transfer ownership and update settings

## Beginner Quickstart (Devnet)

Follow these steps if you’re new to Sui and want an end-to-end setup on devnet: build USDC, deploy the faucet, and mint yourself test USDC.

TL;DR — one-command automation (if your USDC has devnet_helper)

```bash
# From this repo's sui/ folder and with these files in the CURRENT directory:
#   ./devnet-usdc.json   (USDC publish output)
#   ./publish.out.json   (faucet publish output)
#   ./init.out.json      (faucet init output; created by script if TRY_INIT=1 and cap is AddressOwner)

TRY_GRANT=1 TRY_INIT=1 ./discover.sh && source ./discover.env
```

What this does:
- If your USDC exposes `devnet_helper::grant_treasury_cap_to_recipient`, it grants the TreasuryCap to your wallet (AddressOwner).
- If `FAUCET_PACKAGE` is known, it initializes the Faucet and writes `init.out.json`.
- It writes everything needed for the backend into `./discover.env`: `USDC_PACKAGE`, `TREASURY`, `TREASURY_CAP`, `TREASURY_CAP_OWNER_KIND`, `FAUCET_PACKAGE`, `FAUCET_ID`, `FULLNODE_URL`, `CLOCK`.

1) Install tools and select devnet

```bash
# Install Sui CLI (see docs.sui.io for your OS) and jq
# Then select the devnet environment and fund your address
sui client switch --env devnet
sui client faucet

# Verify you have SUI to pay for gas
sui client gas
```

2) Build and publish USDC (Circle reference implementation)

```bash
git clone https://github.com/circlefin/stablecoin-sui.git
cd stablecoin-sui/packages/usdc

# Publish USDC to devnet (large gas budget; includes unpublished deps)
sui client publish --gas-budget 300000000 --with-unpublished-dependencies --json | tee devnet-usdc.json

# Extract the key IDs from the publish result
export USDC_PACKAGE=$(jq -r '.objectChanges[] | select(.type=="published") | .packageId' devnet-usdc.json)
export TREASURY=$(jq -r '.objectChanges[] | select(.type=="created" and (.objectType | test("::treasury::Treasury<.*::usdc::USDC>"))) | .objectId' devnet-usdc.json)
export TREASURY_CAP=$(jq -r '.objectChanges[] | select(.type=="created" and (.objectType | test("0x2::coin::TreasuryCap<.*::usdc::USDC>"))) | .objectId' devnet-usdc.json)
echo "USDC_PACKAGE=$USDC_PACKAGE" && echo "TREASURY=$TREASURY" && echo "TREASURY_CAP=$TREASURY_CAP"


sui client publish --gas-budget 500000000 --with-unpublished-dependencies --json | tee publish.out.json


export FAUCET_PACKAGE=$(jq -r '.objectChanges[] | select(.type=="published") | .packageId' publish.out.json)
echo "FAUCET_PACKAGE=$FAUCET_PACKAGE"

export CLOCK=0x6

# If TREASURY_CAP is not owned by your address, you may need to issue/transfer it
# (function name can vary by version; see README section below for details)

Important:
- The public devnet USDC package (e.g. `0xbca4...0a3a`) is not suitable for initializing your faucet — you do not control its Treasury and cannot get an address-owned `TreasuryCap<USDC>`. Always use your own USDC deployment (the `USDC_PACKAGE` you just published above).

2b) Ensure your TreasuryCap<USDC> is address-owned (required)

```bash
# Check current ownership (AddressOwner is required; ObjectOwner means it's under the Treasury)
sui client object $TREASURY_CAP --json | jq '.data.owner'

## If it shows ObjectOwner
You must transfer/issue a `TreasuryCap<USDC>` to your wallet.

- Option 1: Your USDC already exposes a transfer function (e.g. in `treasury`). Use the Advanced discovery below to find and call it.
- Option 2: Use a Circle USDC build that exposes such a function.
- Option 3 (recommended for devnet): Use your devnet-only helper (`devnet_helper`) to grant the cap to your wallet (see 2b-alt). Then continue.

### Advanced: Discover a cap function via JSON-RPC (only if you don’t use devnet_helper)
# Or use Explorer: https://suiexplorer.com/object/USDC_PACKAGE?network=devnet
# Replace USDC_PACKAGE with your value; look for functions that issue/transfer a TreasuryCap to a recipient.
# 1) List all modules in your USDC package
curl -s -X POST https://fullnode.devnet.sui.io:443 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getNormalizedMoveModulesByPackage","params":["'"$USDC_PACKAGE"'"]}' \
  | jq -r '.result | keys[]'

# 2) Inspect a module's exposed functions and filter for cap-related names
#    Replace MODULE below with one from the output above (try "treasury" first). Repeat if needed.
MODULE=treasury
curl -s -X POST https://fullnode.devnet.sui.io:443 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getNormalizedMoveModule","params":["'"$USDC_PACKAGE"'","'"$MODULE"'"]}' \
  | jq -r '.result.exposedFunctions
           | to_entries[]
           | select((.key | test("cap|issue|transfer|release|grant"; "i")) or ((.value.parameters|tostring) | test("TreasuryCap|USDC"; "i")))
           | .key'

# 3) Call the correct function you found (replace MODULE and FUNCTION with exact names)
MODULE=treasury
FUNCTION=<exact_function_name_here>
sui client call \
  --package $USDC_PACKAGE \
  --module $MODULE \
  --function $FUNCTION \
  --args $TREASURY $(sui client active-address) \
  --type-args $USDC_PACKAGE::usdc::USDC \
  --gas-budget 50000000

# If you cannot find any function that issues/transfers a TreasuryCap<USDC>:
# - Use a different Circle USDC version that exposes it, OR
# - Fork the package for devnet and add a helper to transfer a cap to your address, OR
# - For testing, deploy a simpler devnet coin where you control the cap.

# Re-discover a now address-owned cap (supports Sui CLI 1.55/1.56 JSON shapes)
export TREASURY_CAP=$(sui client objects $(sui client active-address) --json \
  | jq -r --arg PKG "$USDC_PACKAGE" '(.data // .)[] | select(.type | test("TreasuryCap<" + $PKG + "::usdc::USDC>")) | .objectId' \
  | head -n1)

# Sanity-check that it is AddressOwner
sui client object $TREASURY_CAP --json | jq '.data.owner'
echo "TREASURY_CAP=$TREASURY_CAP"
```

2b-alt) If your USDC fork includes `devnet_helper` (recommended on devnet)

If you added a devnet-only helper to your Circle USDC package that can grant the `TreasuryCap<USDC>` to a recipient, call it once to move the cap to your wallet:

```bash
# Grant the TreasuryCap<USDC> to your active address
sui client call \
  --package $USDC_PACKAGE \
  --module devnet_helper \
  --function grant_treasury_cap_to_recipient \
  --args $TREASURY $(sui client active-address) \
  --gas-budget 50000000

# Re-discover a now address-owned cap and verify
export TREASURY_CAP=$(sui client objects $(sui client active-address) --json \
  | jq -r --arg PKG "$USDC_PACKAGE" '(.data // .)[] | select(.type | test("TreasuryCap<" + $PKG + "::usdc::USDC>")) | .objectId' \
  | head -n1)

sui client object $TREASURY_CAP --json | jq '.data.owner'
```

2c) Use the helper script to automate (supports `devnet_helper`)

```bash
# From this repo's sui/ folder. By default it reads files in the CURRENT directory:
#   - ./devnet-usdc.json   (USDC publish)
#   - ./publish.out.json   (faucet publish)
#   - ./init.out.json      (faucet init; created if TRY_INIT=1 and cap is AddressOwner)
# It writes ./discover.env with all exports for backend/.env.

# Basic (no arguments, current directory files)
./discover.sh

# Optional flags:
# - TRY_GRANT=1: If TREASURY_CAP is ObjectOwner and your USDC exposes
#   devnet_helper::grant_treasury_cap_to_recipient, the script calls it to
#   grant the cap to your wallet, then refreshes TREASURY_CAP and owner.
# - TRY_INIT=1: If TREASURY_CAP is AddressOwner and FAUCET_PACKAGE is known,
#   the script initializes the Faucet and writes ./init.out.json.

TRY_GRANT=1 TRY_INIT=1 ./discover.sh

# Or pass explicit paths (absolute or relative)
TRY_GRANT=1 TRY_INIT=1 ./discover.sh ./devnet-usdc.json ./publish.out.json ./init.out.json

# Load all exports into your shell for convenience
source ./discover.env
```

3) Build and publish the USDC Faucet

```bash
# In a separate terminal or after returning to this repo
cd /path/to/sui-usdc-faucet

sui move build

# Publish faucet (large budget recommended if dependencies need publishing)
sui client publish --gas-budget 500000000 --with-unpublished-dependencies --json | tee publish.out.json

export FAUCET_PACKAGE=$(jq -r '.objectChanges[] | select(.type=="published") | .packageId' publish.out.json)
echo "FAUCET_PACKAGE=$FAUCET_PACKAGE"
```

4) Initialize the Faucet with your TreasuryCap<USDC>

```bash
export CLOCK=0x6

# Prerequisite: $TREASURY_CAP must be AddressOwner (see step 2b). If it's ObjectOwner under the Treasury,
# init_faucet will fail with "Objects owned by other objects cannot be used as input arguments".

sui client call --package $FAUCET_PACKAGE --module faucet --function init_faucet --args $TREASURY_CAP --gas-budget 10000000 --json | tee init.out.json

export FAUCET_ID=$(jq -r '.objectChanges[] | select(.type=="created" and (.objectType|endswith("::faucet::Faucet"))) | .objectId' init.out.json)
echo "FAUCET_ID=$FAUCET_ID"
```

5) Mint yourself test USDC via the Faucet

```bash
# Example: 100 USDC (100 * 10^6 = 100000000)
sui client call \
  --package $FAUCET_PACKAGE \
  --module faucet \
  --function request_tokens \
  --args $FAUCET_ID 100000000 $CLOCK \
  --gas-budget 10000000

# Verify you own Coin<USDC>
sui client objects $(sui client active-address) --json \
  | jq -r --arg PKG "$USDC_PACKAGE" '(.data // .)[] | select(.type | test("0x2::coin::Coin<" + $PKG + "::usdc::USDC>")) | .objectId'
```

If anything fails, see the Troubleshooting section below.

## Contract Structure

### Key Components

- **Faucet**: Main shared object that manages the faucet state
- **TreasuryCap<USDC>**: Capability used to mint USDC via the Sui coin module. The USDC deployer (or an authorized role) must transfer this to the Faucet during initialization.
- **Rate Limiting**: Tracks user requests by address and timestamp

### Constants

```move
const USDC_MULTIPLIER: u64 = 1_000_000;                // 10^6 decimals
const MAX_REQUEST_AMOUNT: u64 = 1_000_000 * USDC_MULTIPLIER; // 1,000,000 USDC
const RATE_LIMIT_PERIOD: u64 = 86_400_000;             // 24 hours in ms
const MAX_REQUESTS_PER_PERIOD: u64 = 3;                // Max requests per period
```

## Prerequisites

1. **Sui CLI**: Install the Sui command line tool
2. **USDC Package/Deployment**: An on-chain USDC package and its coin type (e.g., devnet)
3. **TreasuryCap<USDC>**: The USDC TreasuryCap object, controlled by the USDC deployer/authority
4. **Sui Devnet**: Connected to Sui devnet network

## Usage Examples

### Request USDC Tokens

```bash
# Request 100 USDC (100 * 10^6 = 100000000 units)
sui client call \
  --package $FAUCET_PACKAGE \
  --module faucet \
  --function request_tokens \
  --args $FAUCET_ID 100000000 $CLOCK \
  --gas-budget 10000000
```

### Server-signed flow (mint to a recipient without wallet)

This package also exposes a function that mints to a specified recipient address (used by the backend signer):

```move
public fun request_tokens_for(
    faucet: &mut Faucet,
    recipient: address,
    amount: u64,
    clock: &Clock,
    ctx: &mut TxContext,
)
```

It applies the same rate limits as `request_tokens`, keyed by the recipient address. Example CLI call:

```bash
# 50 USDC to 0xRECIPIENT
sui client call \
  --package $FAUCET_PACKAGE \
  --module faucet \
  --function request_tokens_for \
  --args $FAUCET_ID 0xRECIPIENT 50000000 $CLOCK \
  --gas-budget 10000000
```

Note: If you modified the Move code to add `request_tokens_for`, you must build and publish a new faucet package and re-initialize the Faucet (see steps above) to use the updated module on-chain.

### Transfer Faucet Ownership

```bash
# Transfer ownership to another address
sui client call \
  --package $FAUCET_PACKAGE \
  --module faucet \
  --function transfer_ownership \
  --args $FAUCET_ID $NEW_OWNER \
  --gas-budget 10000000
```

## Avoid hardcoding Object IDs

Always derive IDs from your own publish output JSON (captured with `--json | tee <file>`). Use the `jq` snippets shown above to extract:

- USDC package ID
- Treasury object ID (if applicable)
- TreasuryCap<USDC> object ID
- Faucet package ID and Faucet object ID after initialization

Note: The Sui framework Clock is a shared object at `0x6`.

### Tutorial: Find your TreasuryCap<USDC> ID

You can discover your `TreasuryCap<USDC>` object in several ways. Pick the one that matches your situation.

1) From your publish output JSON (fastest)

If you captured the publish output (e.g., `faucet.json`), you can extract the created `TreasuryCap<USDC>` ID directly:

```bash
jq -r '.objectChanges[]
  | select(.type=="created" and (.objectType | test("0x2::coin::TreasuryCap<.*::usdc::USDC>")))
  | .objectId' faucet.json
```

This prints the `TREASURY_CAP` object ID. Set it for later steps:

```bash
export TREASURY_CAP=0xYOUR_TREASURY_CAP_ID
```

2) By searching your owned objects (requires the USDC package ID)

If you know the USDC package ID and you control the cap, search your address for a `TreasuryCap<USDC>`:

```bash
export USDC_PACKAGE=0xYOUR_USDC_PACKAGE_ID
sui client objects $(sui client active-address) --json \
  | jq -r --arg PKG "$USDC_PACKAGE" \
    '(.data // .)[] | select(.type | test("TreasuryCap<" + $PKG + "::usdc::USDC>")) | .objectId'
```

3) From the Treasury object via dynamic fields (advanced)

If you have the Treasury object ID, you can inspect its dynamic fields to locate the `TreasuryCap` entry:

```bash
export TREASURY=0xYOUR_TREASURY_OBJECT_ID
sui client dynamic-fields --object-id $TREASURY --json \
  | jq -r '.data[] | select(.name.type | contains("TreasuryCapKey"))'

# Then inspect the referenced object ID from the output to confirm it's a TreasuryCap<USDC>
sui client object 0xPOTENTIAL_TREASURY_CAP_ID
```

## Rate Limiting Details

- **Maximum Requests per Period**: 3 requests
- **Rate Limit Period**: 24 hours (86,400,000 milliseconds)
- **Maximum Amount per Request**: 1,000,000 USDC
- **Tracking**: Requests are tracked per user address with timestamps

## Events

The faucet emits `FaucetRequest` events for all token requests:

```move
public struct FaucetRequest has copy, drop {
    user: address,
    amount: u64,
    timestamp: u64,
}
```

## Security Considerations

1. **Rate Limiting**: Prevents abuse by limiting requests per user
2. **Amount Limits**: Prevents large withdrawals that could drain the faucet
3. **Owner Controls**: Only the owner can modify faucet settings
4. **TreasuryCap Security**: The TreasuryCap<USDC> should be securely stored (held by the Faucet) and not leaked
5. **USDC Integration**: Ensure you are interacting with the correct USDC package on your network

## Testing

After obtaining USDC from the faucet, you can test Protocol interactions:

1. **Deposit to Treasury**: Use the obtained USDC to deposit
2. **Open Positions**: Use the deposited collateral to open leveraged positions
3. **Market Interactions**: Test various market operations with real USDC collateral

## Troubleshooting

### Common Issues

1. **"Rate limit exceeded"**: Wait 24 hours or use a different address
2. **"Faucet missing TreasuryCap"**: Re-initialize the faucet with a valid TreasuryCap<USDC>
3. **"Wrong USDC package"**: Verify the USDC coin type matches your network/package ID
4. **"Amount too large"**: Request smaller amounts (max 1,000,000 USDC)

### Finding Object IDs

```bash
# Find your TreasuryCap<USDC> (replace USDC package below)
export USDC_PACKAGE=0xYOUR_USDC_PACKAGE_ID
sui client objects $(sui client active-address) --json \
  | jq -r --arg PKG "$USDC_PACKAGE" '(.data // .)[] | select(.type|test("TreasuryCap<" + $PKG + "::usdc::USDC>")) | .objectId'

# Inspect your Faucet object
sui client object $FAUCET_ID
```
