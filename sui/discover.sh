#!/usr/bin/env bash
set -euo pipefail

# discover.sh — auto-discover cap issuance function for Circle USDC build
# Usage:
#   source ./discover.sh [devnet-usdc.json] [publish.out.json] [init.out.json]
#   ./discover.sh   [devnet-usdc.json] [publish.out.json] [init.out.json]
# If omitted (no args), this script will look for files in the CURRENT directory:
#   JSON_PATH   = ./devnet-usdc.json
#   PUBLISH_JSON= ./publish.out.json
#   INIT_JSON   = ./init.out.json

JSON_PATH=${1:-${JSON_PATH:-devnet-usdc.json}}
PUBLISH_JSON=${2:-${PUBLISH_JSON:-publish.out.json}}
INIT_JSON=${3:-${INIT_JSON:-init.out.json}}
# Fullnode endpoint (can be overridden via env NODE)
NODE=${NODE:-https://fullnode.devnet.sui.io:443}

# sanity: deps
for bin in jq curl sui; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Error: '$bin' is required but not found in PATH" >&2; exit 1;
  fi
done

if [ ! -f "$JSON_PATH" ]; then
  echo "Error: JSON_PATH '$JSON_PATH' not found" >&2; exit 1;
fi

# 0) Derive IDs from your publish JSON
export USDC_PACKAGE=$(jq -r '.objectChanges[] | select(.type=="published") | .packageId' "$JSON_PATH")
export TREASURY=$(jq -r '.objectChanges[] | select(.type=="created" and (.objectType | test("::treasury::Treasury<.*::usdc::USDC>"))) | .objectId' "$JSON_PATH")
export TREASURY_CAP=$(jq -r '.objectChanges[] | select(.type=="created" and (.objectType | test("0x2::coin::TreasuryCap<.*::usdc::USDC>"))) | .objectId' "$JSON_PATH")

echo "USDC_PACKAGE=$USDC_PACKAGE"
echo "TREASURY=$TREASURY"
echo "TREASURY_CAP=$TREASURY_CAP"

# prepare env file
ENV_OUT="$(dirname "$JSON_PATH")/discover.env"
{
  echo "export USDC_PACKAGE=$USDC_PACKAGE"
  echo "export TREASURY=$TREASURY"
  echo "export TREASURY_CAP=$TREASURY_CAP"
} > "$ENV_OUT"

# 1) Ownership check
OWNER_KIND=$(sui client object "$TREASURY_CAP" --json | jq -r '(.data.owner // .owner) | keys[0]')
echo "TREASURY_CAP owner kind: $OWNER_KIND"
echo "export TREASURY_CAP_OWNER_KIND=$OWNER_KIND" >> "$ENV_OUT"

# If cap is still ObjectOwner, check for devnet_helper availability and optionally grant
HELPER_AVAILABLE=""
if [ "$OWNER_KIND" = "ObjectOwner" ]; then
  HELPER_AVAILABLE=$(curl -s -X POST "$NODE" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"sui_getNormalizedMoveModule","params":["'"$USDC_PACKAGE"'","devnet_helper"]}' \
    | jq -r 'if (.result.exposedFunctions // {} | has("grant_treasury_cap_to_recipient")) then "1" else "" end' 2>/dev/null || true)

  if [ -n "$HELPER_AVAILABLE" ]; then
    echo "Detected devnet_helper::grant_treasury_cap_to_recipient in your USDC package."
    echo "You can transfer the TreasuryCap<USDC> to your wallet with:"
    cat << CMD
  sui client call \
    --package $USDC_PACKAGE \
    --module devnet_helper \
    --function grant_treasury_cap_to_recipient \
    --args $TREASURY $(sui client active-address) \
    --gas-budget 50000000
CMD

    if [ "${TRY_GRANT:-}" = "1" ]; then
      echo "TRY_GRANT=1 set. Attempting to grant TreasuryCap to active address..."
      sui client call \
        --package "$USDC_PACKAGE" \
        --module devnet_helper \
        --function grant_treasury_cap_to_recipient \
        --args "$TREASURY" "$(sui client active-address)" \
        --gas-budget 50000000 --json | tee grant.out.json || echo "Warning: grant call failed."

      # Re-discover a cap now owned by address
      NEW_CAP=$(sui client objects $(sui client active-address) --json \
        | jq -r --arg PKG "$USDC_PACKAGE" '(.data // .)[] | select(.type | test("TreasuryCap<" + $PKG + "::usdc::USDC>")) | .objectId' \
        | head -n1)
      if [ -n "$NEW_CAP" ]; then
        TREASURY_CAP="$NEW_CAP"
        echo "export TREASURY_CAP=$TREASURY_CAP" >> "$ENV_OUT"
        echo "Updated TREASURY_CAP=$TREASURY_CAP"
        OWNER_KIND=$(sui client object "$TREASURY_CAP" --json | jq -r '(.data.owner // .owner) | keys[0]')
        echo "TREASURY_CAP owner kind: $OWNER_KIND"
        echo "export TREASURY_CAP_OWNER_KIND=$OWNER_KIND" >> "$ENV_OUT"
      fi
    fi
  fi
fi

# 2) Discover modules and cap-related functions
MODULES=$(curl -s -X POST "$NODE" \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getNormalizedMoveModulesByPackage","params":["'"$USDC_PACKAGE"'"]}' \
  | jq -r '.result | keys[]')

FOUND_MODULE=""
FOUND_FUNC=""
for M in $MODULES; do
  FUNCS=$(curl -s -X POST "$NODE" -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"sui_getNormalizedMoveModule","params":["'"$USDC_PACKAGE"'","'"$M"'"]}' \
    | jq -r '.result.exposedFunctions | to_entries[] | select((.key | test("cap|treasury_cap|mint_cap"; "i")) or ((.value.parameters|tostring) | test("TreasuryCap<"; "i"))) | .key' \
    | { grep -Ev '^(transfer_ownership|begin_role_transfer)$' || true; } \
    | sort -u)

  if [ -n "$FUNCS" ]; then
    echo "== Module: $M =="
    echo "$FUNCS" | sed 's/^/  - /'
    COUNT=$(echo "$FUNCS" | wc -l | tr -d ' ')
    if [ "$COUNT" = "1" ] && [ -z "$FOUND_MODULE" ]; then
      FOUND_MODULE="$M"
      FOUND_FUNC="$FUNCS"
    fi
  fi
done

# 3) Export MODULE/FUNCTION if a unique candidate was found; otherwise print guidance
if [ -n "$FOUND_MODULE" ] && [ -n "$FOUND_FUNC" ]; then
  export MODULE="$FOUND_MODULE"
  export FUNCTION="$FOUND_FUNC"
  echo "export MODULE=$MODULE"
  echo "export FUNCTION=$FUNCTION"
  {
    echo "export MODULE=$MODULE"
    echo "export FUNCTION=$FUNCTION"
  } >> "$ENV_OUT"
  printf "\nCall example:\n"
  cat << EOF
sui client call \
  --package $USDC_PACKAGE \
  --module $MODULE \
  --function $FUNCTION \
  --args $TREASURY $(sui client active-address) \
  --type-args $USDC_PACKAGE::usdc::USDC \
  --gas-budget 50000000
EOF
else
  echo "No unique cap-issuance function found. Manually set, if applicable:"
  echo "  export MODULE=<module_name>"
  echo "  export FUNCTION=<function_name>"
  echo "If none exists in your USDC package, use a Circle build that exposes it or fork for devnet and add a helper."
  if [ -n "$HELPER_AVAILABLE" ]; then
    echo "(Helper detected) Tip: set TRY_GRANT=1 and re-run to auto-grant the cap to your wallet."
  fi
  echo ""
  echo "To add a devnet helper to your Circle USDC fork (Option B):"
  echo "1. Add this line to your usdc::treasury module (near the top):"
  echo "     friend usdc::devnet_helper;"
  echo "2. Add this function in the same module (adjust field name if needed):"
  echo "     public(friend) fun devnet_transfer_treasury_cap(t: &mut Treasury<USDC>, recipient: address) {"
  echo "         transfer::public_transfer(t.treasury_cap, recipient); // adjust field name if not .treasury_cap"
  echo "     }"
  echo "3. Create a new file sources/devnet_helper.move with:"
  cat << 'EOF'
module usdc::devnet_helper {
    use sui::tx_context::TxContext;
    use usdc::treasury;
    use usdc::usdc::USDC;

    public entry fun grant_treasury_cap_to_recipient(
        t: &mut treasury::Treasury<USDC>,
        recipient: address,
        _ctx: &mut TxContext
    ) {
        treasury::devnet_transfer_treasury_cap(t, recipient);
    }
}
EOF
  echo "4. Re-publish USDC and call devnet_helper::grant_treasury_cap_to_recipient"
  echo "   to transfer the cap to your address. Then re-run this script."
fi

printf "\nWrote exportable values to: %s\n" "$ENV_OUT"
echo "To load them in your shell: source $ENV_OUT"

# 4) (Optional) Discover faucet package/id for backend env
# Fallbacks: if files not found in current dir, try parent dir
if [ ! -f "$PUBLISH_JSON" ]; then
  for CAND in "./publish.out.json" "../publish.out.json"; do
    if [ -f "$CAND" ]; then PUBLISH_JSON="$CAND"; break; fi
  done
fi
if [ ! -f "$INIT_JSON" ]; then
  for CAND in "./init.out.json" "../init.out.json"; do
    if [ -f "$CAND" ]; then INIT_JSON="$CAND"; break; fi
  done
fi

if [ -f "$PUBLISH_JSON" ]; then
  FAUCET_PACKAGE=$(jq -r '.objectChanges[] | select(.type=="published") | .packageId' "$PUBLISH_JSON")
  if [ -n "${FAUCET_PACKAGE:-}" ] && [ "$FAUCET_PACKAGE" != "null" ]; then
    export FAUCET_PACKAGE
    echo "FAUCET_PACKAGE=$FAUCET_PACKAGE"
    echo "export FAUCET_PACKAGE=$FAUCET_PACKAGE" >> "$ENV_OUT"
  else
    # ensure placeholder exists in env file
    echo "export FAUCET_PACKAGE=" >> "$ENV_OUT"
  fi
else
  echo "Note: faucet publish JSON not found at $PUBLISH_JSON (set PUBLISH_JSON to override)"
  echo "export FAUCET_PACKAGE=" >> "$ENV_OUT"
fi

# Validate faucet links against your USDC package (Move.toml addresses)
USDC_LINK_MISMATCH=0
if [ -f "./Move.toml" ]; then
  CURRENT_USDC_ADDR=$(grep -E '^[[:space:]]*usdc[[:space:]]*=' ./Move.toml | head -n1 | sed -E 's/.*=\s*"([^"]+)".*/\1/' || true)
  if [ -n "$CURRENT_USDC_ADDR" ] && [ -n "${USDC_PACKAGE:-}" ] && [ "$CURRENT_USDC_ADDR" != "$USDC_PACKAGE" ]; then
    USDC_LINK_MISMATCH=1
    echo "Warning: Move.toml addresses.usdc=$CURRENT_USDC_ADDR differs from USDC_PACKAGE=$USDC_PACKAGE"
    echo "This will cause TypeMismatch when calling init_faucet."
    echo "Fix it with one of the following:"
    echo "  # Option A: auto-patch (TRY_PATCH=1)"
    echo "  TRY_PATCH=1 ./discover.sh"
    echo "  # Option B: manual patch"
    echo "  sed -i -E 's/^[[:space:]]*usdc[[:space:]]*=.*/usdc = \"$USDC_PACKAGE\"/' Move.toml"
    echo "Then rebuild and re-publish the faucet in this folder, and re-run this script:"
    echo "  sui move build && sui client publish --gas-budget 500000000 --with-unpublished-dependencies --json | tee publish.out.json"
  fi

  if [ "$USDC_LINK_MISMATCH" = "1" ] && [ "${TRY_PATCH:-}" = "1" ]; then
    if grep -qE '^[[:space:]]*usdc[[:space:]]*=' ./Move.toml ; then
      sed -i -E "s/^[[:space:]]*usdc[[:space:]]*=.*/usdc = \"$USDC_PACKAGE\"/" ./Move.toml
      echo "Patched Move.toml addresses.usdc to $USDC_PACKAGE"
    else
      if grep -q '^\[addresses\]' ./Move.toml ; then
        # append under addresses section (simple append at end)
        printf "\nusdc = \"%s\"\n" "$USDC_PACKAGE" >> ./Move.toml
      else
        printf "\n[addresses]\nusdc = \"%s\"\n" "$USDC_PACKAGE" >> ./Move.toml
      fi
      echo "Added addresses.usdc=$USDC_PACKAGE to Move.toml"
    fi
    echo "Now rebuild and publish the faucet from this folder, then re-run discover.sh:"
    echo "  sui move build && sui client publish --gas-budget 500000000 --with-unpublished-dependencies --json | tee publish.out.json"
  fi
fi

# Optionally attempt init if missing and allowed
if [ ! -f "$INIT_JSON" ] && [ "${TRY_INIT:-}" = "1" ]; then
  if [ "$USDC_LINK_MISMATCH" = "1" ]; then
    echo "Skipping TRY_INIT due to USDC linkage mismatch. Patch Move.toml and re-publish faucet first."
  else
  # Ensure FAUCET_PACKAGE is resolved before init attempt by re-parsing PUBLISH_JSON if needed
  if [ -z "${FAUCET_PACKAGE:-}" ] && [ -f "$PUBLISH_JSON" ]; then
    FAUCET_PACKAGE=$(jq -r '.objectChanges[] | select(.type=="published") | .packageId' "$PUBLISH_JSON")
    if [ -n "${FAUCET_PACKAGE:-}" ] && [ "$FAUCET_PACKAGE" != "null" ]; then
      export FAUCET_PACKAGE
      echo "FAUCET_PACKAGE=$FAUCET_PACKAGE"
      echo "export FAUCET_PACKAGE=$FAUCET_PACKAGE" >> "$ENV_OUT"
    fi
  fi

  if [ "${OWNER_KIND}" = "AddressOwner" ] && [ -n "${FAUCET_PACKAGE:-}" ]; then
    echo "INIT_JSON not found and TRY_INIT=1 set. Attempting faucet init -> $INIT_JSON"
    sui client call \
      --package "$FAUCET_PACKAGE" \
      --module faucet \
      --function init_faucet \
      --args "$TREASURY_CAP" \
      --gas-budget 10000000 \
      --json | tee "$INIT_JSON" || echo "Warning: init_faucet call failed. Check caps and gas."
  else
    echo "TRY_INIT=1 set but cannot init automatically: OWNER_KIND=$OWNER_KIND, FAUCET_PACKAGE='${FAUCET_PACKAGE:-}'"
    echo "Ensure AddressOwner TreasuryCap and set FAUCET_PACKAGE, then re-run."
  fi
  fi
fi

if [ -f "$INIT_JSON" ]; then
  FAUCET_ID=$(jq -r '.objectChanges[] | select(.type=="created" and (.objectType|endswith("::faucet::Faucet"))) | .objectId' "$INIT_JSON")
  if [ -n "${FAUCET_ID:-}" ] && [ "$FAUCET_ID" != "null" ]; then
    export FAUCET_ID
    echo "FAUCET_ID=$FAUCET_ID"
    echo "export FAUCET_ID=$FAUCET_ID" >> "$ENV_OUT"
  else
    echo "Note: Faucet object not found in $INIT_JSON (init may have failed)."
    echo "export FAUCET_ID=" >> "$ENV_OUT"
  fi
else
  echo "Note: faucet init JSON not found at $INIT_JSON (set INIT_JSON to override)"
  echo "export FAUCET_ID=" >> "$ENV_OUT"

fi

# 5) Backend env suggestion
FULLNODE_URL_DEFAULT=${FULLNODE_URL:-$NODE}
CLOCK_DEFAULT=${CLOCK:-0x6}
echo "export FULLNODE_URL=$FULLNODE_URL_DEFAULT" >> "$ENV_OUT"
echo "export CLOCK=$CLOCK_DEFAULT" >> "$ENV_OUT"

printf "\nBackend .env suggestion (copy these lines):\n"
cat << BACKEND_ENV
PORT=8787
FULLNODE_URL=$FULLNODE_URL_DEFAULT
FAUCET_PACKAGE=${FAUCET_PACKAGE:-}
FAUCET_ID=${FAUCET_ID:-}
CLOCK=$CLOCK_DEFAULT
SUI_PRIVATE_KEY=0x<your_ed25519_secret_hex>
BACKEND_ENV