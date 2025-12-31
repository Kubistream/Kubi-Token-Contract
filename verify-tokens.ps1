# Token Verification Script for Windows
# Run after deployment to verify all 10 tokens on BaseScan

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   KUBI TOKEN VERIFICATION SCRIPT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Read addresses from user
Write-Host "STEP 1: Copy addresses from deployment output" -ForegroundColor Yellow
Write-Host "Look for lines like: Deployed MUSDC at: 0x..." -ForegroundColor Gray
Write-Host ""
Write-Host "STEP 2: Paste all 10 addresses below" -ForegroundColor Yellow
Write-Host "Order: MUSDC, MUSDT, MNT, METH, MPUFF, MAXL, MSVL, MLINK, MWBTC, MPENDLE" -ForegroundColor Gray
Write-Host ""
$Input = Read-Host "Paste addresses here (space or comma separated)"

# Parse addresses
$Addrs = $Input -split '[,\s]+' | Where-Object { $_ -match '^0x[a-fA-F0-9]{40}$' }

if ($Addrs.Count -ne 10) {
    Write-Host "❌ Error: Need exactly 10 valid addresses! Got: $($Addrs.Count)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Found $($Addrs.Count) addresses:" -ForegroundColor Green
for ($i = 0; $i -lt $Addrs.Count; $i++) {
    Write-Host "  [$($i+1)] $($Addrs[$i])" -ForegroundColor Gray
}
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Token configurations
$Symbols = @("MUSDC", "MUSDT", "MNT", "METH", "MPUFF", "MAXL", "MSVL", "MLINK", "MWBTC", "MPENDLE")
$Names = @(
    "Kubi USD Coin",
    "Kubi Tether USD",
    "Kubi Mantle Token",
    "Kubi Ether",
    "Kubi Puffer Token",
    "Kubi Axelar Token",
    "Kubi SSV Network Token",
    "Kubi Chainlink Token",
    "Kubi Wrapped BTC",
    "Kubi Pendle Token"
)
$Decimals = @(18, 18, 18, 18, 18, 18, 18, 18, 8, 18)

# Get env variables
$Mailbox = $env:MAILBOX
$Owner = $env:OWNER
$InitialSupply = $env:INITIAL_SUPPLY
$Igp = $env:INTERCHAIN_GAS_PAYMASTER
$Ism = $env:INTERCHAIN_SECURITY_MODULE
$ApiKey = $env:BASESCAN_API_KEY

if (-not $Mailbox -or -not $Owner) {
    Write-Host "❌ Error: Please set environment variables in .env file!" -ForegroundColor Red
    Write-Host "   Required: MAILBOX, OWNER, INITIAL_SUPPLY" -ForegroundColor Gray
    exit 1
}

Write-Host "========================================"
Write-Host "Starting verification..." -ForegroundColor Cyan
Write-Host "========================================"
Write-Host ""

# Verify each token
$Success = 0
$Failed = 0

for ($i = 0; $i -lt $Addrs.Count; $i++) {
    $Sym = $Symbols[$i]
    $Addr = $Addrs[$i]
    $Name = $Names[$i]
    $Dec = $Decimals[$i]

    Write-Host "[$($i+1)/10] Verifying $Sym..." -ForegroundColor Cyan
    Write-Host "       Address: $Addr" -ForegroundColor Gray

    # Encode constructor args
    $DecimalsForCast = $Dec
    if ($Dec -eq 8) {
        $DecimalsForCast = "8"
    }

    $CtorArgs = cast abi-encode `
        "constructor(address,uint8,string,string,address,address,address,uint256)" `
        $Mailbox $DecimalsForCast $Name $Sym $Igp $Ism $Owner $InitialSupply

    # Verify contract
    $Result = forge verify-contract $Addr `
        src/TokenHypERC20.sol:TokenHypERC20 `
        --chain-id 84532 `
        --constructor-args $CtorArgs `
        --etherscan-api-key $ApiKey `
        --watch 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "       ✅ Verified!" -ForegroundColor Green
        $Success++
    } else {
        Write-Host "       ⚠️  Failed or already verified" -ForegroundColor Yellow
        $Failed++
    }

    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "VERIFICATION SUMMARY" -ForegroundColor Cyan
Write-Host "  ✅ Success: $Success" -ForegroundColor Green
Write-Host "  ❌ Failed:  $Failed" -ForegroundColor $(if ($Failed -gt 0) { "Red" } else { "Gray" })
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($Success -eq 10) {
    Write-Host "🎉 All tokens verified successfully!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Some verifications failed. Check errors above." -ForegroundColor Yellow
}
