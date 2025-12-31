#!/bin/bash
# Multi-chain token verification script
# Usage: ./verify-multi-chain.sh [base|mantle]
#
# Examples:
#   ./verify-multi-chain.sh base     # Verify on Base Sepolia
#   ./verify-multi-chain.sh mantle   # Verify on Mantle Sepolia

# Don't exit on error - we handle errors manually in the loop
# set -e

# Chain configuration
declare -A CHAIN_IDS
declare -A VERIFIER_URLS
declare -A API_KEY_ENVS
declare -A BROADCAST_DIRS

CHAIN_IDS[base]=84532
CHAIN_IDS[mantle]=5003

# Use correct API endpoints
VERIFIER_URLS[base]="https://api-sepolia.basescan.org/api"
VERIFIER_URLS[mantle]="https://api-sepolia.mantlescan.xyz/api"

API_KEY_ENVS[base]="BASESCAN_API_KEY"
API_KEY_ENVS[mantle]="MANTLESCAN_API_KEY"

BROADCAST_DIRS[base]="broadcast/DeployTokensDirect.s.sol/84532"
BROADCAST_DIRS[mantle]="broadcast/DeployTokensDirect.s.sol/5003"

# Default chain
CHAIN="${1:-base}"

# Validate chain parameter
if [[ "$CHAIN" != "base" && "$CHAIN" != "mantle" ]]; then
    echo "❌ Error: Invalid chain '$CHAIN'"
    echo ""
    echo "Usage: $0 [base|mantle]"
    echo ""
    echo "Examples:"
    echo "  $0 base    # Verify on Base Sepolia"
    echo "  $0 mantle  # Verify on Mantle Sepolia"
    exit 1
fi

# Get chain-specific config
CHAIN_ID="${CHAIN_IDS[$CHAIN]}"
VERIFIER_URL="${VERIFIER_URLS[$CHAIN]}"
API_KEY_ENV="${API_KEY_ENVS[$CHAIN]}"
BROADCAST_DIR="${BROADCAST_DIRS[$CHAIN]}"
API_KEY="${!API_KEY_ENV:-PCFEF9SR9NAJYM3B7C9KSX73Y6N9YVKVGH}"

# Chain name for display
CHAIN_NAME="Base Sepolia"
RPC_URL="$BASE_RPC_URL"
if [[ "$CHAIN" == "mantle" ]]; then
    CHAIN_NAME="Mantle Sepolia"
    RPC_URL="$MANTLE_RPC_URL"
fi

echo "=========================================="
echo "   Token Verification - $CHAIN_NAME"
echo "=========================================="
echo "   Chain ID: $CHAIN_ID"
echo "   Verifier: $VERIFIER_URL"
echo "=========================================="
echo ""

# Check required environment variables
if [ -z "$MAILBOX" ]; then
    echo "❌ Error: MAILBOX environment variable is not set!"
    echo "   Please run: source .env"
    echo "   Or set MAILBOX manually: export MAILBOX=0x..."
    exit 1
fi

# Check RPC URL
if [ -z "$RPC_URL" ]; then
    echo "⚠️  Warning: RPC URL not set (${CHAIN^^}_RPC_URL)"
    echo "   Verification may fail without RPC URL"
    echo ""
fi

echo "📋 Environment check:"
echo "   MAILBOX: $MAILBOX"
echo "   OWNER: ${OWNER:-<derived from PRIVATE_KEY>}"
echo "   IGP: ${INTERCHAIN_GAS_PAYMASTER:-0x0000000000000000000000000000000000000000}"
echo "   ISM: ${INTERCHAIN_SECURITY_MODULE:-0x0000000000000000000000000000000000000000}"
echo "   INITIAL_SUPPLY: ${INITIAL_SUPPLY:-<not set>}"
echo "   RPC_URL: ${RPC_URL:-<not set>}"
echo ""

# Check if deployment exists
if [ ! -d "$BROADCAST_DIR" ]; then
    echo "❌ Error: No deployment found for $CHAIN_NAME!"
    echo "   Expected directory: $BROADCAST_DIR"
    echo ""
    echo "Please deploy tokens first:"
    echo "   forge script script/DeployTokensDirect.s.sol --rpc-url <${CHAIN}_RPC_URL> --broadcast"
    exit 1
fi

# Get latest deployment file
LATEST_JSON="$BROADCAST_DIR/run-latest.json"
if [ ! -f "$LATEST_JSON" ]; then
    echo "❌ Error: No deployment output found!"
    exit 1
fi

echo "📂 Reading deployment from: $LATEST_JSON"
echo ""

# Extract addresses from deployment log
ADDRESSES=$(
  jq -r '.returns.deployedAddresses.value // empty' "$LATEST_JSON" 2>/dev/null \
  | sed 's/^\[//; s/\]$//' \
  | tr ',' '\n' \
  | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
  | sed '/^$/d' \
  | head -n 10
)

if [ -z "$ADDRESSES" ]; then
    echo "❌ Error: Could not extract addresses from deployment!"
    echo ""
    echo "📝 Please enter addresses manually (space-separated):"
    echo "   Order: MUSDC MUSDT MNT METH MPUFF MAXL MSVL MLINK MWBTC MPENDLE"
    echo ""
    read -p "Enter 10 addresses: " ADDR_INPUT
    ADDRESSES=$(echo $ADDR_INPUT | tr ' ' '\n')
fi

# Convert to array
ADDR_ARRAY=()
while IFS= read -r addr; do
    ADDR_ARRAY+=("$addr")
done <<< "$ADDRESSES"

if [ ${#ADDR_ARRAY[@]} -ne 10 ]; then
    echo "❌ Error: Need exactly 10 addresses!"
    echo "   Found: ${#ADDR_ARRAY[@]}"
    exit 1
fi

# Token configurations
SYMBOLS=(MUSDC MUSDT MNT METH MPUFF MAXL MSVL MLINK MWBTC MPENDLE)
NAMES=(
    "Kubi USD Coin"
    "Kubi Tether USD"
    "Kubi Mantle Token"
    "Kubi Ether"
    "Kubi Puffer Token"
    "Kubi Axelar Token"
    "Kubi SSV Network Token"
    "Kubi Chainlink Token"
    "Kubi Wrapped BTC"
    "Kubi Pendle Token"
)
DECIMALS=(18 18 18 18 18 18 18 18 8 18)

# Use default values for optional params (as used in deployment)
: "${INTERCHAIN_GAS_PAYMASTER:=0x0000000000000000000000000000000000000000}"
: "${INTERCHAIN_SECURITY_MODULE:=0x0000000000000000000000000000000000000000}"

echo "Found ${#ADDR_ARRAY[@]} token addresses:"
for i in "${!ADDR_ARRAY[@]}"; do
    echo "  ${SYMBOLS[$i]}: ${ADDR_ARRAY[$i]}"
done
echo ""
echo "=========================================="
echo ""

# Verify each token
SUCCESS_COUNT=0
FAILED_COUNT=0

for i in "${!ADDR_ARRAY[@]}"; do
    SYM="${SYMBOLS[$i]}"
    ADDR="${ADDR_ARRAY[$i]}"
    NAME="${NAMES[$i]}"
    DEC="${DECIMALS[$i]}"

    echo "🔍 Verifying $SYM..."
    echo "   Address: $ADDR"

    # Encode constructor arguments
    CTOR_ARGS=$(cast abi-encode \
        "constructor(address,uint8,string,string,address,address,address,uint256)" \
        "$MAILBOX" "$DEC" "$NAME" "$SYM" \
        "$INTERCHAIN_GAS_PAYMASTER" "$INTERCHAIN_SECURITY_MODULE" \
        "$OWNER" "$INITIAL_SUPPLY" 2>&1)

    if [[ "$CTOR_ARGS" == *"error"* ]] || [ -z "$CTOR_ARGS" ]; then
        echo "   ❌ Failed to encode constructor args"
        echo "   Error: $CTOR_ARGS"
        ((FAILED_COUNT++))
        continue
    fi

    echo "   Constructor args encoded"

    # Build forge verify command with RPC if available
    VERIFY_CMD="forge verify-contract $ADDR src/TokenHypERC20.sol:TokenHypERC20"
    VERIFY_CMD="$VERIFY_CMD --etherscan-api-key $API_KEY"
    VERIFY_CMD="$VERIFY_CMD --constructor-args $CTOR_ARGS"
    
    # Add RPC URL if available (helps with fetching bytecode)
    if [ -n "$RPC_URL" ]; then
        VERIFY_CMD="$VERIFY_CMD --rpc-url $RPC_URL"
    else
        VERIFY_CMD="$VERIFY_CMD --chain-id $CHAIN_ID"
    fi
    
    # Add compiler settings matching foundry.toml
    VERIFY_CMD="$VERIFY_CMD --num-of-optimizations 200"
    VERIFY_CMD="$VERIFY_CMD --via-ir"
    VERIFY_CMD="$VERIFY_CMD --watch"

    echo "   Running: forge verify-contract $ADDR ..."
    
    VERIFY_OUTPUT=$(eval "$VERIFY_CMD" 2>&1) || true

    echo "   Output:"
    echo "$VERIFY_OUTPUT" | head -20 | sed 's/^/   /'

    if echo "$VERIFY_OUTPUT" | grep -qiE "successfully verified|already verified|contract .* is already verified|submitted for verification"; then
        echo "   ✅ Verified or submitted!"
        ((SUCCESS_COUNT++))
    else
        echo "   ❌ Verification failed"
        ((FAILED_COUNT++))
    fi

    echo ""
    
    # Delay between verifications to avoid rate limiting
    sleep 3
done

echo "=========================================="
echo "Verification Summary ($CHAIN_NAME):"
echo "  ✅ Success: $SUCCESS_COUNT"
echo "  ❌ Failed:  $FAILED_COUNT"
echo "=========================================="
echo ""

if [ $SUCCESS_COUNT -eq 10 ]; then
    echo "🎉 All tokens verified successfully on $CHAIN_NAME!"
    exit 0
else
    echo "⚠️  Some verifications failed."
    echo "   Check the errors above or verify manually."
    exit 1
fi
