#!/bin/bash
# Auto-verify all deployed tokens
# Run this after deployment completes

CHAIN_ID=84532
VERIFIER_URL="https://api-sepolia.basescan.org/api"
API_KEY="${BASESCAN_API_KEY}"

echo "Starting verification of all deployed tokens..."
echo ""

# Token configurations (must match deployment)
declare -A TOKENS
TOKENS["MUSDC"]="Kubi USD Coin:18"
TOKENS["MUSDT"]="Kubi Tether USD:18"
TOKENS["MNT"]="Kubi Mantle Token:18"
TOKENS["METH"]="Kubi Ether:18"
TOKENS["MPUFF"]="Kubi Puffer Token:18"
TOKENS["MAXL"]="Kubi Axelar Token:18"
TOKENS["MSVL"]="Kubi SSV Network Token:18"
TOKENS["MLINK"]="Kubi Chainlink Token:18"
TOKENS["MWBTC"]="Kubi Wrapped BTC:8"
TOKENS["MPENDLE"]="Kubi Pendle Token:18"

# Read addresses from deployment output or prompt user
echo "Enter deployed addresses (space-separated, in order MUSDC MPENDLE):"
read -r ADDR1 ADDR2 ADDR3 ADDR4 ADDR5 ADDR6 ADDR7 ADDR8 ADDR9 ADDR10

ADDRS=($ADDR1 $ADDR2 $ADDR3 $ADDR4 $ADDR5 $ADDR6 $ADDR7 $ADDR8 $ADDR9 $ADDR10)
SYMBOLS=(MUSDC MUSDT MNT METH MPUFF MAXL MSVL MLINK MWBTC MPENDLE)

for i in "${!SYMBOLS[@]}"; do
    SYM="${SYMBOLS[$i]}"
    ADDR="${ADDRS[$i]}"

    # Get token info
    INFO="${TOKENS[$SYM]}"
    NAME="${INFO%:*}"
    DEC="${INFO##*:}"

    echo ""
    echo "Verifying $SYM at $ADDR..."

    # Encode constructor arguments
    CTOR_ARGS=$(cast abi-encode \
        "constructor(address,uint8,string,string,address,address,address,uint256)" \
        "$MAILBOX" "$DEC" "$NAME" "$SYM" \
        "$INTERCHAIN_GAS_PAYMASTER" "$INTERCHAIN_SECURITY_MODULE" \
        "$OWNER" "$INITIAL_SUPPLY")

    # Verify contract
    forge verify-contract "$ADDR" \
        src/TokenHypERC20.sol:TokenHypERC20 \
        --chain-id "$CHAIN_ID" \
        --verifier-url "$VERIFIER_URL" \
        --constructor-args "$CTOR_ARGS" \
        --etherscan-api-key "$API_KEY" \
        --watch

    echo ""
    echo "✅ $SYM verified!"
    echo "---"
done

echo ""
echo "==================================="
echo "All tokens verified successfully!"
echo "==================================="
