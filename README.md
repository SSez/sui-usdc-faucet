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

# If TREASURY_CAP is not owned by your address, you may need to issue/transfer it
# (function name can vary by version; see README section below for details)
```

3) Build and publish the Aquilo USDC Faucet

```bash
# In a separate terminal or after returning to this repo
cd /home/user/Documents/git/aquilo/sui/faucet

sui move build

# Publish faucet (large budget recommended if dependencies need publishing)
sui client publish --gas-budget 500000000 --with-unpublished-dependencies --json | tee publish.out.json

export FAUCET_PACKAGE=$(jq -r '.objectChanges[] | select(.type=="published") | .packageId' publish.out.json)
echo "FAUCET_PACKAGE=$FAUCET_PACKAGE"
```

4) Initialize the Faucet with your TreasuryCap<USDC>

```bash
export CLOCK=0x6

sui client call \
  --package $FAUCET_PACKAGE \
  --module faucet \
  --function init_faucet \
  --args $TREASURY_CAP \
  --gas-budget 10000000 \
  --json | tee init.out.json

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
sui client objects --address $(sui client active-address) --json \
  | jq -r --arg PKG "$USDC_PACKAGE" '.data[] | select(.type | test("0x2::coin::Coin<" + $PKG + "::usdc::USDC>")) | .objectId'
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

## Setup Instructions

### 1. Deploy the Faucet Contract

```bash
# Navigate to the faucet directory
cd /path/to/aquilo/sui/faucet

# Build the contract
sui move build

# Publish to devnet
# Note: If dependencies are not published on your target network, add --with-unpublished-dependencies
sui client publish --gas-budget 500000000 --with-unpublished-dependencies --json | tee publish.out.json

# Export the published package ID (FAUCET_PACKAGE)
export FAUCET_PACKAGE=$(jq -r '.objectChanges[] | select(.type=="published") | .packageId' publish.out.json)
echo "FAUCET_PACKAGE=$FAUCET_PACKAGE"
```

### 2. Identify your USDC deployment and TreasuryCap

You will need the USDC package ID and the TreasuryCap<USDC> object ID. Set environment variables once you have them:

```bash
# Example (replace with your own IDs)
export USDC_PACKAGE=0xbca409c719d46e966ea3fe4e9fe10e81254a6f803c03771f84e67cb73c3f0a3a
export TREASURY_CAP=0xYOUR_TREASURY_CAP_ID
export CLOCK=0x6
```

### 3. Initialize the Faucet

```bash
# Initialize faucet by transferring the TreasuryCap<USDC> into the Faucet
sui client call \
  --package $FAUCET_PACKAGE \
  --module faucet \
  --function init_faucet \
  --args $TREASURY_CAP \
  --gas-budget 10000000 \
  --json | tee init.out.json

# Export the created Faucet object ID (FAUCET_ID)
export FAUCET_ID=$(jq -r '.objectChanges[] | select(.type=="created" and (.objectType|endswith("::faucet::Faucet"))) | .objectId' init.out.json)
echo "FAUCET_ID=$FAUCET_ID"
```

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

## Key Object IDs (Devnet)

If you're using the current Aquilo devnet USDC deployment (as in `frontend/src/config.ts`):

- **USDC Package ID**: `0xbca409c719d46e966ea3fe4e9fe10e81254a6f803c03771f84e67cb73c3f0a3a`
- **Treasury Object ID**: `0x3861bddb0fdcc9e783c41d774071ce45684d1e7b118f4be06062bb3c9e44e466`
- **TreasuryCap ID**: `<fill with your TreasuryCap<USDC> object id>`
- **Clock (Framework singleton)**: `0x6`

### Tutorial: Find your TreasuryCap<USDC> ID

You can discover your `TreasuryCap<USDC>` object in several ways. Pick the one that matches your situation.

1) From your publish output JSON (fastest)

If you captured the publish output (e.g., `sui/faucet/faucet.json`), you can extract the created `TreasuryCap<USDC>` ID directly:

```bash
jq -r '.objectChanges[]
  | select(.type=="created" and (.objectType | test("0x2::coin::TreasuryCap<.*::usdc::USDC>")))
  | .objectId' /home/user/Documents/git/aquilo/sui/faucet/faucet.json
```

This prints the `TREASURY_CAP` object ID. Set it for later steps:

```bash
export TREASURY_CAP=0xYOUR_TREASURY_CAP_ID
```

2) By searching your owned objects (requires the USDC package ID)

If you know the USDC package ID and you control the cap, search your address for a `TreasuryCap<USDC>`:

```bash
export USDC_PACKAGE=0xbca409c719d46e966ea3fe4e9fe10e81254a6f803c03771f84e67cb73c3f0a3a
sui client objects --address $(sui client active-address) --json \
  | jq -r --arg PKG "$USDC_PACKAGE" \
    '.data[] | select(.type | test("TreasuryCap<" + $PKG + "::usdc::USDC>")) | .objectId'
```

3) From the Treasury object via dynamic fields (advanced)

If you have the Treasury object ID, you can inspect its dynamic fields to locate the `TreasuryCap` entry:

```bash
export TREASURY=0x3861bddb0fdcc9e783c41d774071ce45684d1e7b118f4be06062bb3c9e44e466
sui client dynamic-fields --object-id $TREASURY --json \
  | jq -r '.data[] | select(.name.type | contains("TreasuryCapKey"))'

# Then inspect the referenced object ID from the output to confirm it's a TreasuryCap<USDC>
sui client object 0xPOTENTIAL_TREASURY_CAP_ID
```

### Devnet Quickstart

## Build and deploy USDC from scratch (devnet)

If you don’t have a USDC deployment yet, you can build and publish Circle’s reference USDC package on devnet. This will give you the USDC package ID, the Treasury object, and a TreasuryCap<USDC> object.

```bash
# 1) Clone Circle's stablecoin repo
git clone https://github.com/circlefin/stablecoin-sui.git
cd stablecoin-sui/packages/usdc

# 2) Publish USDC to devnet (large gas budget recommended)
sui client publish --gas-budget 300000000 --with-unpublished-dependencies --json | tee devnet-usdc.json

# 3) Extract useful IDs from the publish output
export USDC_PACKAGE=$(jq -r '.objectChanges[] \
  | select(.type=="published") \
  | .packageId' devnet-usdc.json)

export TREASURY=$(jq -r '.objectChanges[] \
  | select(.type=="created" and (.objectType | test("::treasury::Treasury<.*::usdc::USDC>"))) \
  | .objectId' devnet-usdc.json)

export TREASURY_CAP=$(jq -r '.objectChanges[] \
  | select(.type=="created" and (.objectType | test("0x2::coin::TreasuryCap<.*::usdc::USDC>"))) \
  | .objectId' devnet-usdc.json)

echo "USDC_PACKAGE=$USDC_PACKAGE"
echo "TREASURY=$TREASURY"
echo "TREASURY_CAP=$TREASURY_CAP"

# (Optional) Inspect the created objects
sui client object $TREASURY
sui client object $TREASURY_CAP
```

Notes:
- Some Circle builds store `TreasuryCap<USDC>` under the `Treasury` as a dynamic field. If the cap is not address-owned, you may need to call a function from the `treasury` module to issue or transfer the `TreasuryCap` to your address before you can pass it to `init_faucet`.
- If your USDC build exposes a function like `issue_treasury_cap` (name may vary), you can try:

```bash
# Example only — function name/signature may vary by version
sui client call \
  --package $USDC_PACKAGE \
  --module treasury \
  --function issue_treasury_cap \
  --args $TREASURY $(sui client active-address) \
  --type-args $USDC_PACKAGE::usdc::USDC \
  --gas-budget 50000000

# After issuing, re-discover a now address-owned TreasuryCap<USDC>:
sui client objects --address $(sui client active-address) --json \
  | jq -r --arg PKG "$USDC_PACKAGE" \
      '.data[] | select(.type | test("TreasuryCap<" + $PKG + "::usdc::USDC>")) | .objectId'
```

Once you have `USDC_PACKAGE`, `TREASURY` and an address-owned `TREASURY_CAP`, proceed to initialize the faucet as shown above.

```bash
# IDs from current devnet config (update as needed)
export USDC_PACKAGE=0xbca409c719d46e966ea3fe4e9fe10e81254a6f803c03771f84e67cb73c3f0a3a
export TREASURY=0x3861bddb0fdcc9e783c41d774071ce45684d1e7b118f4be06062bb3c9e44e466
export TREASURY_CAP=0xYOUR_TREASURY_CAP_ID
export CLOCK=0x6                    # Clock shared object

# Faucet deployment artifacts (replace with your deployed values; must start with 0x)
export FAUCET_PACKAGE=0xYOUR_FAUCET_PACKAGE_ID
export FAUCET_ID=0xYOUR_FAUCET_ID

# Optional: quick sanity check for ObjectID format
for v in USDC_PACKAGE TREASURY TREASURY_CAP FAUCET_PACKAGE FAUCET_ID; do \
  eval val=\${$v}; \
  if ! [[ $val =~ ^0x[0-9a-fA-F]+$ ]]; then echo "ERROR: $v must be a 0x-prefixed hex ObjectID (current: '$val')"; fi; \
done

# Optional: publish faucet now and capture FAUCET_PACKAGE automatically
sui client publish --gas-budget 100000000 --with-unpublished-dependencies --json | tee publish.out.json
export FAUCET_PACKAGE=$(jq -r '.objectChanges[] | select(.type=="published") | .packageId' publish.out.json)
echo "FAUCET_PACKAGE=$FAUCET_PACKAGE"

# Initialize the faucet
sui client call \
  --package $FAUCET_PACKAGE \
  --module faucet \
  --function init_faucet \
  --args $TREASURY_CAP \
  --gas-budget 10000000 \
  --json | tee init.out.json

export FAUCET_ID=$(jq -r '.objectChanges[] | select(.type=="created" and (.objectType|endswith("::faucet::Faucet"))) | .objectId' init.out.json)
echo "FAUCET_ID=$FAUCET_ID"

# Request 100 USDC
sui client call \
  --package $FAUCET_PACKAGE \
  --module faucet \
  --function request_tokens \
  --args $FAUCET_ID 100000000 $CLOCK \
  --gas-budget 10000000
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

## Testing with Aquilo Protocol

After obtaining USDC from the faucet, you can test Aquilo Protocol interactions:

1. **Deposit to Treasury**: Use the obtained USDC to deposit into Aquilo's account system
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
USDC_PACKAGE=0xbca409c719d46e966ea3fe4e9fe10e81254a6f803c03771f84e67cb73c3f0a3a
sui client objects --address $(sui client active-address) --json \
  | jq -r --arg PKG "$USDC_PACKAGE" '.data[] | select(.type|test("TreasuryCap<" + $PKG + "::usdc::USDC>")) | .objectId'

# Inspect your Faucet object
sui client object $FAUCET_ID
```

## Contributing

When modifying the faucet:

1. Update rate limiting parameters if needed
2. Test thoroughly on devnet before mainnet deployment
3. Ensure proper error handling and event logging
4. Update documentation for any new features

## License

This faucet contract is part of the Aquilo Protocol and follows the same licensing terms.
