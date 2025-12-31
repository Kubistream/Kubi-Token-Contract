# Kubi Token Contracts

Solidity contracts and scripts for Kubi tokens (Hyperlane-enabled ERC20) and yield-bearing wrappers.

## Quick commands
- Build: `forge build`
- Test: `forge test`
- Format: `forge fmt`
- Gas snapshot: `forge snapshot`

## Deploy Hyperlane tokens
See `DEPLOY_TOKENS.md` for full flow. Typical broadcast:
```bash
forge script script/DeployTokensDirect.s.sol \
  --rpc-url <RPC_URL> \
  --broadcast \
  -vvv
```

## Deploy TokenYield (Mantle Sepolia example)
Use a dedicated env file to avoid touching your Hyperc20 `.env`.
```bash
ENV_FILE=.env.mantle-yields
forge script script/DeployMultipleTokenYields.s.sol \
  --rpc-url https://rpc.sepolia.mantle.xyz \
  --chain-id 5003 \
  --broadcast \
  --env-file $ENV_FILE \
  -vvv
```

## Verify TokenYield
Batch verify 20 yield tokens using the helper script:
```bash
ENV_FILE=.env.mantle-yields scripts/verify-token-yields.sh
```
Defaults: reads `broadcast/DeployMultipleTokenYields.s.sol/5003/run-latest.json`, uses Mantle Sepolia Blockscout. Override with `BROADCAST_DIR`, `VERIFIER_URL`, `RPC_URL`, or `API_KEY` if needed.

## Environment variables
Set these in your env file before deploying TokenYield. Token-level underlying looks up in order: token override > protocol default > global default.

- Global: `PRIVATE_KEY`, `DEFAULT_UNDERLYING_TOKEN`, `DEFAULT_VAULT_ADDRESS`, `DEFAULT_DEPOSITOR_CONTRACT`

### Minterest (mi*)
- Defaults: `MINTEREST_DEFAULT_UNDERLYING`, `MINTEREST_DEFAULT_VAULT`, `MINTEREST_DEFAULT_DEPOSITOR`
- Token overrides: `MINTEREST_USDC_UNDERLYING`, `MINTEREST_USDT_UNDERLYING`, `MINTEREST_MNT_UNDERLYING`, `MINTEREST_BTC_UNDERLYING`, `MINTEREST_ETH_UNDERLYING`

### Lendle (le*)
- Defaults: `LENDLE_DEFAULT_UNDERLYING`, `LENDLE_DEFAULT_VAULT`, `LENDLE_DEFAULT_DEPOSITOR`
- Token overrides: `LENDLE_USDC_UNDERLYING`, `LENDLE_USDT_UNDERLYING`, `LENDLE_MNT_UNDERLYING`, `LENDLE_BTC_UNDERLYING`, `LENDLE_ETH_UNDERLYING`

### INIT Capital (ic*)
- Defaults: `INIT_CAPITAL_DEFAULT_UNDERLYING`, `INIT_CAPITAL_DEFAULT_VAULT`, `INIT_CAPITAL_DEFAULT_DEPOSITOR`
- Token overrides: `INIT_CAPITAL_USDC_UNDERLYING`, `INIT_CAPITAL_USDT_UNDERLYING`, `INIT_CAPITAL_MNT_UNDERLYING`, `INIT_CAPITAL_BTC_UNDERLYING`, `INIT_CAPITAL_ETH_UNDERLYING`

### Compound (co*)
- Defaults: `COMPOUND_DEFAULT_UNDERLYING`, `COMPOUND_DEFAULT_VAULT`, `COMPOUND_DEFAULT_DEPOSITOR`
- Token overrides: `COMPOUND_USDC_UNDERLYING`, `COMPOUND_USDT_UNDERLYING`, `COMPOUND_MNT_UNDERLYING`, `COMPOUND_BTC_UNDERLYING`, `COMPOUND_ETH_UNDERLYING`
