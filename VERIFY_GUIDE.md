# Token Contract Verification Guide

This guide explains how to verify your deployed token contracts on block explorers.

## Verification Scripts

### 1. **verify-multi-chain.sh** - Single Chain Verification (Recommended)

Verify tokens on a specific chain with auto-detection of deployment addresses.

```bash
# Verify on Base Sepolia
./verify-multi-chain.sh base

# Verify on Mantle Sepolia
./verify-multi-chain.sh mantle
```

**Features:**
- Automatically reads addresses from `broadcast/DeployTokensDirect.s.sol/<CHAIN_ID>/run-latest.json`
- Falls back to manual address entry if auto-detection fails
- Supports both Base Sepolia and Mantle Sepolia
- Shows detailed verification progress

---

### 2. **verify-both-chains.sh** - Dual Chain Verification

Verify tokens on BOTH chains in one command.

```bash
./verify-both-chains.sh
```

**What it does:**
1. Verifies all 10 tokens on Base Sepolia
2. Verifies all 10 tokens on Mantle Sepolia
3. Shows combined summary at the end

**Use case:** After deploying tokens to both chains

---

### 3. **verify-simple.sh** - Manual Address Entry

Simple verification script where you manually paste addresses.

```bash
# Verify on Base Sepolia (default)
./verify-simple.sh

# Verify on Base Sepolia (explicit)
./verify-simple.sh base

# Verify on Mantle Sepolia
./verify-simple.sh mantle
```

**Use case:** When auto-detection fails or you want to verify specific addresses

---

### 4. **verify-tokens.sh** - Base Sepolia Only (Legacy)

Original verification script for Base Sepolia only.

```bash
./verify-tokens.sh
```

**Note:** This script is hardcoded for Base Sepolia only. Use `verify-multi-chain.sh` instead for multi-chain support.

---

### 5. **verify-tokens.ps1** - Windows PowerShell

PowerShell verification script for Windows users.

```powershell
.\verify-tokens.ps1
```

**Note:** Currently Base Sepolia only. Need to enhance for Mantle Sepolia support.

---

## Quick Start Workflow

### Scenario 1: Deployed to Base Sepolia Only

```bash
# 1. Deploy tokens
forge script script/DeployTokensDirect.s.sol \
  --rpc-url $BASE_RPC_URL \
  --broadcast

# 2. Verify on Base Sepolia
./verify-multi-chain.sh base
```

### Scenario 2: Deployed to Both Chains

```bash
# 1. Deploy to Base Sepolia
forge script script/DeployTokensDirect.s.sol \
  --rpc-url $BASE_RPC_URL \
  --broadcast

# 2. Deploy to Mantle Sepolia (same SALT = same addresses!)
forge script script/DeployTokensDirect.s.sol \
  --rpc-url $MANTLE_RPC_URL \
  --broadcast

# 3. Verify on both chains
./verify-both-chains.sh
```

### Scenario 3: Manual Address Entry

If auto-detection fails, use the simple script:

```bash
./verify-simple.sh mantle
# Then paste your 10 token addresses
```

---

## Chain Configuration

| Chain | Chain ID | Explorer | API Key Env Var |
|-------|----------|----------|-----------------|
| Base Sepolia | 84532 | https://sepolia.basescan.org | `BASESCAN_API_KEY` |
| Mantle Sepolia | 5003 | https://sepolia.mantlescan.xyz | `MANTLESCAN_API_KEY` |

---

## Environment Variables Required

Ensure these are set in your `.env` file and loaded:

```bash
# Hyperlane infrastructure
MAILBOX=0x9Be84C76636B5F01Dcac2ea8955e5eb6E3Aa27a5
INTERCHAIN_GAS_PAYMASTER=0x0000000000000000000000000000000000000000
INTERCHAIN_SECURITY_MODULE=0x0000000000000000000000000000000000000000

# Token config
OWNER=0x1234562eb0cd65e7d08e59f9f18d7c10b5df232a
INITIAL_SUPPLY=1000000000000000000000000

# Explorer API keys
BASESCAN_API_KEY=PCFEF9SR9NAJYM3B7C9KSX73Y6N9YVKVGH
MANTLESCAN_API_KEY=PCFEF9SR9NAJYM3B7C9KSX73Y6N9YVKVGH
```

Load environment variables:

```bash
# For bash/zsh
source .env

# Or export manually
export $(cat .env | grep -v '^#' | xargs)
```

---

## Troubleshooting

### Error: "No deployment found!"

**Cause:** No broadcast directory exists for the specified chain.

**Solution:**
1. Make sure you've deployed tokens to that chain
2. Check if `broadcast/DeployTokensDirect.s.sol/<CHAIN_ID>/` directory exists

### Error: "Could not extract addresses from deployment!"

**Cause:** Auto-detection failed (maybe jq not installed or JSON format changed)

**Solution:** Use `verify-simple.sh` and paste addresses manually

### Error: "Failed to encode constructor args"

**Cause:** Environment variables not loaded

**Solution:**
```bash
source .env
# Then retry verification
```

### Verification fails with "Already verified"

**Cause:** Contract is already verified on the explorer

**Solution:** This is not an error! The script will continue with remaining tokens

### Error: "Need exactly 10 addresses!"

**Cause:** Manual address entry has wrong number of addresses

**Solution:** Make sure you paste all 10 addresses in the correct order:
```
MUSDC MUSDT MNT METH MPUFF MAXL MSVL MLINK MWBTC MPENDLE
```

---

## Verification Output Examples

### Successful Verification

```
==========================================
   Token Verification - Base Sepolia
==========================================
   Chain ID: 84532
   Verifier: https://api-sepolia.basescan.org/api
==========================================

Found 10 token addresses:
  MUSDC: 0x6200D151724d6f41cDA38b8475E075Ad51aFA56f
  MUSDT: 0x8C7a38B63D3b06B73381FaEe638A18e256b08123
  ...

==========================================

🔍 Verifying MUSDC...
   Address: 0x6200D151724d6f41cDA38b8475E075Ad51aFA56f
   ✅ Verified!

...

==========================================
Verification Summary (Base Sepolia):
  ✅ Success: 10
  ❌ Failed:  0
==========================================

🎉 All tokens verified successfully on Base Sepolia!
```

---

## Tips

1. **Always deploy to Base Sepolia first** - It's faster and cheaper to test
2. **Use the same SALT** - This ensures identical addresses across chains
3. **Save your deployment addresses** - Copy them from the deployment output
4. **Verify immediately after deployment** - Don't wait to avoid confusion
5. **Check the explorer manually** - Visit the explorer URL to confirm verification

---

## Related Commands

### Check if contract is verified manually

```bash
# Base Sepolia
cast code 0x<contract-address> --rpc-url https://base-sepolia.g.alchemy.com/v2/YOUR_KEY

# Then visit: https://sepolia.basescan.org/address/0x<contract-address>#code
```

### Get deployment addresses from broadcast

```bash
# Base Sepolia
jq -r '.returns[0].deployedAddresses[]' broadcast/DeployTokensDirect.s.sol/84532/run-latest.json

# Mantle Sepolia
jq -r '.returns[0].deployedAddresses[]' broadcast/DeployTokensDirect.s.sol/5003/run-latest.json
```
