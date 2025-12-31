#!/bin/bash
# Auto-verify tokens from latest deployment
# Automatically reads addresses from broadcast/latest.json

set -e

CHAIN_ID=84532
VERIFIER_URL="https://api-sepolia.basescan.org/api"
API_KEY="${BASESCAN_API_KEY:-PCFEF9SR9NAJYM3B7C9KSX73Y6N9YVKVGH}"

echo "=========================================="
echo "   Token Verification Script"
echo "=========================================="
echo ""

# Check if deployment exists
BROADCAST_DIR="broadcast/DeployTokensDirect.s.sol/84532"
if [ ! -d "$BROADCAST_DIR" ]; then
    echo "❌ Error: No deployment found!"
    echo "   Please deploy tokens first:"
    echo "   forge script script/DeployTokensDirect.s.sol --rpc-url <RPC> --broadcast"
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
# The deployment returns addresses in order
ADDRESSES=$(jq -r '.returns[0].deployedAddresses[]' "$LATEST_JSON" 2>/dev/null || echo "")

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
        "$OWNER" "$INITIAL_SUPPLY" 2>/dev/null)

    if [ -z "$CTOR_ARGS" ]; then
        echo "   ❌ Failed to encode constructor args"
        echo "   Please check environment variables in .env"
        ((FAILED_COUNT++))
        continue
    fi

    # Verify contract
    if forge verify-contract "$ADDR" \
        src/TokenHypERC20.sol:TokenHypERC20 \
        --chain-id "$CHAIN_ID" \
        --verifier-url "$VERIFIER_URL" \
        --constructor-args "$CTOR_ARGS" \
        --etherscan-api-key "$API_KEY" \
        --watch 2>&1 | grep -q "Successfully verified"; then
        echo "   ✅ Verified!"
        ((SUCCESS_COUNT++))
    else
        echo "   ❌ Verification failed or already verified"
        ((FAILED_COUNT++))
    fi

    echo ""
done

echo "=========================================="
echo "Verification Summary:"
echo "  ✅ Success: $SUCCESS_COUNT"
echo "  ❌ Failed:  $FAILED_COUNT"
echo "=========================================="
echo ""

if [ $SUCCESS_COUNT -eq 10 ]; then
    echo "🎉 All tokens verified successfully!"
    exit 0
else
    echo "⚠️  Some verifications failed."
    echo "   Check the errors above or verify manually on BaseScan."
    exit 1
fi
