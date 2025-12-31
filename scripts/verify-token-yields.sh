#!/bin/bash
# Verify TokenYield contracts on Mantle Sepolia.
# Usage:
#   ENV_FILE=.env.mantle-yields scripts/verify-token-yields.sh
# Options (env):
#   ENV_FILE: path to env file (default: .env)
#   BROADCAST_DIR: broadcast dir with run-latest.json (default: broadcast/DeployMultipleTokenYields.s.sol/5003)
#   VERIFIER_URL: verifier API (default: https://explorer.sepolia.mantle.xyz/api)
#   VERIFIER_NAME: verifier type (default: blockscout)
#   RPC_URL: RPC endpoint (default: $MANTLE_RPC_URL from env)
#   API_KEY: verifier API key (default: $MANTLESCAN_API_KEY or dummy)

set -uo pipefail

ENV_FILE="${ENV_FILE:-.env}"
BROADCAST_DIR="${BROADCAST_DIR:-broadcast/DeployMultipleTokenYields.s.sol/5003}"
RUN_JSON="$BROADCAST_DIR/run-latest.json"
VERIFIER_URL="${VERIFIER_URL:-https://api.etherscan.io/v2/api?chainid=5003}"
VERIFIER_NAME="${VERIFIER_NAME:-blockscout}"
RPC_URL="${RPC_URL:-${MANTLE_RPC_URL:-}}"
API_KEY=""
CHAIN_ID=5003

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: ENV_FILE not found: $ENV_FILE"
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

if [ ! -f "$RUN_JSON" ]; then
  echo "Error: run-latest.json not found at $RUN_JSON"
  echo "Deploy first with DeployMultipleTokenYields.s.sol."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq not installed."
  exit 1
fi
if ! command -v cast >/dev/null 2>&1; then
  echo "Error: cast (foundry) not installed."
  exit 1
fi

# Read deployed addresses in creation order (20 tokens total)
mapfile -t ADDRESSES < <(jq -r '
  (.transactions[]?.contractAddress // empty),
  (.receipts[]?.contractAddress // empty),
  (.returns[]?.value[]? // empty)
' "$RUN_JSON" | sed '/^$/d' | head -n 20)

if [ "${#ADDRESSES[@]}" -lt 20 ]; then
  echo "Warning: found ${#ADDRESSES[@]} addresses, expected 20."
  echo "Enter 20 addresses manually (space-separated), in order:"
  echo "miUSDC miUSDT miMNT miBTC miETH leUSDC leUSDT leMNT leBTC leETH icUSDC icUSDT icMNT icBTC icETH coUSDC coUSDT coMNT coBTC coETH"
  read -r -a ADDRESSES
fi

if [ "${#ADDRESSES[@]}" -ne 20 ]; then
  echo "Error: need exactly 20 addresses."
  exit 1
fi

NAMES=(
  "Minterest Staked USDC" "Minterest Staked USDT" "Minterest Staked MNT" "Minterest Staked BTC" "Minterest Staked ETH"
  "Lendle Staked USDC" "Lendle Staked USDT" "Lendle Staked MNT" "Lendle Staked BTC" "Lendle Staked ETH"
  "INIT Capital Staked USDC" "INIT Capital Staked USDT" "INIT Capital Staked MNT" "INIT Capital Staked BTC" "INIT Capital Staked ETH"
  "Compound Staked USDC" "Compound Staked USDT" "Compound Staked MNT" "Compound Staked BTC" "Compound Staked ETH"
)
SYMBOLS=(
  miUSDC miUSDT miMNT miBTC miETH
  leUSDC leUSDT leMNT leBTC leETH
  icUSDC icUSDT icMNT icBTC icETH
  coUSDC coUSDT coMNT coBTC coETH
)
ENV_PREFIXES=(
  MINTEREST MINTEREST MINTEREST MINTEREST MINTEREST
  LENDLE LENDLE LENDLE LENDLE LENDLE
  INIT_CAPITAL INIT_CAPITAL INIT_CAPITAL INIT_CAPITAL INIT_CAPITAL
  COMPOUND COMPOUND COMPOUND COMPOUND COMPOUND
)
TOKEN_KEYS=(
  USDC USDT MNT BTC ETH
  USDC USDT MNT BTC ETH
  USDC USDT MNT BTC ETH
  USDC USDT MNT BTC ETH
)

get_env() {
  local key="$1"
  local val="${!key-}"
  echo "$val"
}

success=0
fail=0

echo "Using verifier: $VERIFIER_URL"
echo "Verifier name: $VERIFIER_NAME"
echo "RPC: ${RPC_URL:-<none>}"
echo "Broadcast log: $RUN_JSON"
echo ""
echo "Found ${#ADDRESSES[@]} addresses:"
printf '  %s\n' "${ADDRESSES[@]}"
echo ""

for idx in "${!ADDRESSES[@]}"; do
  addr="${ADDRESSES[$idx]}"
  name="${NAMES[$idx]}"
  sym="${SYMBOLS[$idx]}"
  prefix="${ENV_PREFIXES[$idx]}"
  tok="${TOKEN_KEYS[$idx]}"

  token_key="${prefix}_${tok}_UNDERLYING"
  proto_default="${prefix}_DEFAULT_UNDERLYING"
  underlying="$(get_env "$token_key")"
  [ -z "$underlying" ] && underlying="$(get_env "$proto_default")"
  [ -z "$underlying" ] && underlying="${DEFAULT_UNDERLYING_TOKEN:-}"

  vault_key="${prefix}_DEFAULT_VAULT"
  vault="${!vault_key-}"
  [ -z "$vault" ] && vault="${DEFAULT_VAULT_ADDRESS:-0x0000000000000000000000000000000000000000}"

  depositor_key="${prefix}_DEFAULT_DEPOSITOR"
  depositor="${!depositor_key-}"
  [ -z "$depositor" ] && depositor="${DEFAULT_DEPOSITOR_CONTRACT:-0x0000000000000000000000000000000000000000}"

  if [ -z "$underlying" ]; then
    echo "Error: missing underlying for $sym (checked $token_key, $proto_default, DEFAULT_UNDERLYING_TOKEN)"
    ((fail++))
    continue
  fi

  ctor_args=$(cast abi-encode \
    "constructor(string,string,address,address,address)" \
    "$name" "$sym" "$underlying" "$vault" "$depositor")

  echo "Verifying $sym at $addr"
  echo "  name: $name"
  echo "  underlying: $underlying"
  echo "  vault: $vault"
  echo "  depositor: $depositor"

  cmd=(forge verify-contract "$addr" src/TokenYield.sol:TokenYield
    --chain-id "$CHAIN_ID"
    --verifier "$VERIFIER_NAME"
    --verifier-url "$VERIFIER_URL"
    --etherscan-api-key "$API_KEY"
    --constructor-args "$ctor_args"
    --watch)
  [ -n "$RPC_URL" ] && cmd+=(--rpc-url "$RPC_URL")

  if "${cmd[@]}"; then
    ((success++))
  else
    ((fail++))
  fi
  echo ""
  sleep 2
done

echo "Done. Success: $success, Failed: $fail"
[ "$fail" -eq 0 ]
