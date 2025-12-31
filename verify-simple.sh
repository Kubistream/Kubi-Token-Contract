#!/bin/bash
# Simple verification script - copy addresses from deployment output
# Run this AFTER deployment completes
#
# Usage: ./verify-simple.sh [base|mantle]
#   base   - Verify on Base Sepolia (default)
#   mantle - Verify on Mantle Sepolia

CHAIN="${1:-base}"

# Chain configuration
if [[ "$CHAIN" == "mantle" ]]; then
    CHAIN_ID=5003
    CHAIN_NAME="Mantle Sepolia"
    VERIFIER_URL="https://api-sepolia.mantlescan.xyz/api"
    API_KEY="${MANTLESCAN_API_KEY:-PCFEF9SR9NAJYM3B7C9KSX73Y6N9YVKVGH}"
else
    CHAIN_ID=84532
    CHAIN_NAME="Base Sepolia"
    VERIFIER_URL="https://api-sepolia.basescan.org/api"
    API_KEY="${BASESCAN_API_KEY:-PCFEF9SR9NAJYM3B7C9KSX73Y6N9YVKVGH}"
fi

echo "=========================================="
echo "   Quick Token Verification - $CHAIN_NAME"
echo "=========================================="
echo "   Chain ID: $CHAIN_ID"
echo "=========================================="
echo ""
echo "📋 STEP 1: Copy addresses from your $CHAIN_NAME deployment output"
echo ""
echo "   Look for lines like this:"
echo "   Deployed MUSDC at: 0x6200D151724d6f41cDA38b8475E075Ad51aFA56f"
echo ""
echo "📋 STEP 2: Paste all 10 addresses below (one per line or space-separated)"
echo ""
echo "   Order: MUSDC, MUSDT, MNT, METH, MPUFF, MAXL, MSVL, MLINK, MWBTC, MPENDLE"
echo ""
read -p "Paste addresses here: " USER_INPUT

# Convert input to array (handle both space and newline separated)
ADDRS=($(echo "$USER_INPUT" | tr '\n' ' ' | tr -s ' '))

if [ ${#ADDRS[@]} -ne 10 ]; then
    echo "❌ Error: Need exactly 10 addresses! Got: ${#ADDRS[@]}"
    exit 1
fi

echo ""
echo "=========================================="
echo "Found addresses:"
for i in "${!ADDRS[@]}"; do
    echo "  [$((i+1))] ${ADDRS[$i]}"
done
echo "=========================================="
echo ""
read -p "Continue with verification? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "=========================================="
echo "Starting verification..."
echo "=========================================="
echo ""

# Token configs
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

# Verify each token
for i in "${!ADDRS[@]}"; do
    SYM="${SYMBOLS[$i]}"
    ADDR="${ADDRS[$i]}"
    NAME="${NAMES[$i]}"
    DEC="${DECIMALS[$i]}"

    echo "[$((i+1))/10] Verifying $SYM at $ADDR..."

    # Get constructor args from env
    CTOR_ARGS=$(cast abi-encode \
        "constructor(address,uint8,string,string,address,address,address,uint256)" \
        "$MAILBOX" "$DEC" "$NAME" "$SYM" \
        "$INTERCHAIN_GAS_PAYMASTER" "$INTERCHAIN_SECURITY_MODULE" \
        "$OWNER" "$INITIAL_SUPPLY")

    # Verify
    forge verify-contract "$ADDR" \
        src/TokenHypERC20.sol:TokenHypERC20 \
        --chain-id "$CHAIN_ID" \
        --verifier-url "$VERIFIER_URL" \
        --constructor-args "$CTOR_ARGS" \
        --etherscan-api-key "$API_KEY" \
        --watch

    echo ""
done

echo "=========================================="
echo "✅ Verification complete on $CHAIN_NAME!"
echo "=========================================="
