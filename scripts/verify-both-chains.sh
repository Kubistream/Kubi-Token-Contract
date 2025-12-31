#!/bin/bash
# Verify tokens on BOTH Base Sepolia and Mantle Sepolia
# This script runs verification on both chains sequentially

echo "=========================================="
echo "   Multi-Chain Token Verification"
echo "=========================================="
echo ""
echo "This will verify all 10 tokens on:"
echo "  1. Base Sepolia (Chain ID: 84532)"
echo "  2. Mantle Sepolia (Chain ID: 5003)"
echo ""

# Check if .env is loaded
if [ -z "$MAILBOX" ] || [ -z "$OWNER" ]; then
    echo "⚠️  Warning: Environment variables not loaded!"
    echo "   Please run: source .env"
    echo ""
    read -p "Continue anyway? (y/n): " CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        exit 1
    fi
fi

read -p "Press Enter to start verification..."

# Verify on Base Sepolia
echo ""
echo "=========================================="
echo "STEP 1: Verifying on Base Sepolia"
echo "=========================================="
echo ""

./verify-multi-chain.sh base
BASE_RESULT=$?

echo ""
echo "=========================================="

# Verify on Mantle Sepolia
echo ""
echo "STEP 2: Verifying on Mantle Sepolia"
echo "=========================================="
echo ""

./verify-multi-chain.sh mantle
MANTLE_RESULT=$?

# Final summary
echo ""
echo "=========================================="
echo "FINAL VERIFICATION SUMMARY"
echo "=========================================="
echo ""

if [ $BASE_RESULT -eq 0 ]; then
    echo "✅ Base Sepolia: All tokens verified"
else
    echo "❌ Base Sepolia: Some verifications failed"
fi

if [ $MANTLE_RESULT -eq 0 ]; then
    echo "✅ Mantle Sepolia: All tokens verified"
else
    echo "❌ Mantle Sepolia: Some verifications failed"
fi

echo ""
echo "=========================================="

if [ $BASE_RESULT -eq 0 ] && [ $MANTLE_RESULT -eq 0 ]; then
    echo "🎉 SUCCESS! All tokens verified on both chains!"
    exit 0
else
    echo "⚠️  Some verifications failed. Check errors above."
    exit 1
fi
