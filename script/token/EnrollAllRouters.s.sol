// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {TypeCasts} from "@hyperlane-xyz/core/libs/TypeCasts.sol";
import {TokenHypERC20} from "../../src/TokenHypERC20.sol";

/// @title Enroll Routers for All Tokens at Once
/// @notice Enrolls remote router for ALL 10 tokens in a single transaction batch
/// @dev Supports bi-directional routing: Base Sepolia <-> Mantle Sepolia
///
/// === USAGE ===
/// # Set environment variables first
/// export PRIVATE_KEY=0x...
/// export BASE_RPC_URL=https://base-sepolia...
/// export MANTLE_RPC_URL=https://mantle-sepolia...
///
/// # Run on Base Sepolia (enrolls Mantle as remote)
/// forge script script/token/EnrollAllRouters.s.sol --rpc-url $BASE_RPC_URL --broadcast -vvv
///
/// # Run on Mantle Sepolia (enrolls Base as remote)
/// forge script script/token/EnrollAllRouters.s.sol --rpc-url $MANTLE_RPC_URL --broadcast -vvv
///
contract EnrollAllRouters is Script {
    using TypeCasts for address;

    // Domain IDs
    uint32 constant BASE_SEPOLIA_DOMAIN = 84532;
    uint32 constant MANTLE_SEPOLIA_DOMAIN = 5003;

    // Token addresses (SAME on both chains via CREATE2)
    address constant MUSDC = 0xB288Ba5B5b80Dd0Fd83541ef2e5922f71121Fa13;
    address constant MUSDT = 0xC4a53c466Cfb62AecED03008B0162baaf36E0B03;
    address constant MNT = 0x33c6f26dA09502E6540043f030aE1F87f109cc99;
    address constant METH = 0x7CB382Ce1AA40FA9F9A59a632090c05Dc28caE7b;
    address constant MPUFF = 0x70Db6eFB75c898Ad1e194FDA2B8C6e73dbC944d6;
    address constant MAXL = 0xEE589FBF85128abA6f42696dB2F28eA9EBddE173;
    address constant MSVL = 0x2C036be74942c597e4d81D7050008dDc11becCEb;
    address constant MLINK = 0x90CdcBF4c4bc78dC440252211EFd744d0A4Dc4A1;
    address constant MWBTC = 0xced6Ceb47301F268d57fF07879DF45Fda80e6974;
    address constant MPENDLE = 0x782Ba48189AF93a0CF42766058DE83291f384bF3;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        uint32 currentDomain = uint32(block.chainid);

        // Determine remote domain based on current chain
        uint32 remoteDomain;
        string memory currentChainName;
        string memory remoteChainName;

        if (currentDomain == BASE_SEPOLIA_DOMAIN) {
            remoteDomain = MANTLE_SEPOLIA_DOMAIN;
            currentChainName = "Base Sepolia";
            remoteChainName = "Mantle Sepolia";
        } else if (currentDomain == MANTLE_SEPOLIA_DOMAIN) {
            remoteDomain = BASE_SEPOLIA_DOMAIN;
            currentChainName = "Mantle Sepolia";
            remoteChainName = "Base Sepolia";
        } else {
            revert("Unsupported chain. Use Base Sepolia (84532) or Mantle Sepolia (5003)");
        }

        console.log("\n=== ENROLL ALL ROUTERS ===");
        console.log("Current Chain:", currentChainName);
        console.log("Remote Chain:", remoteChainName);
        console.log("Remote Domain:", remoteDomain);
        console.log("===========================\n");

        // List of all tokens to enroll
        address[10] memory tokens = [
            MUSDC,
            MUSDT,
            MNT,
            METH,
            MPUFF,
            MAXL,
            MSVL,
            MLINK,
            MWBTC,
            MPENDLE
        ];

        string[10] memory symbols = [
            "MUSDC",
            "MUSDT",
            "MNT",
            "METH",
            "MPUFF",
            "MAXL",
            "MSVL",
            "MLINK",
            "MWBTC",
            "MPENDLE"
        ];

        vm.startBroadcast(pk);

        uint256 successCount = 0;
        uint256 skipCount = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenAddr = tokens[i];
            string memory symbol = symbols[i];

            TokenHypERC20 token = TokenHypERC20(tokenAddr);

            // Check if already enrolled
            bytes32 existingRouter = token.routers(remoteDomain);
            if (existingRouter != bytes32(0)) {
                console.log(unicode"⏭️  ", symbol, "already enrolled, skipping");
                skipCount++;
                continue;
            }

            // Since tokens have same address on both chains (CREATE2),
            // the remote router is the same address as the local token
            token.enrollRemoteRouter(remoteDomain, tokenAddr.addressToBytes32());
            console.log(unicode"✅ ", symbol, "enrolled ->", tokenAddr);
            successCount++;
        }

        vm.stopBroadcast();

        console.log("\n=== SUMMARY ===");
        console.log("Enrolled:", successCount);
        console.log("Skipped (already enrolled):", skipCount);
        console.log("Total:", tokens.length);
        console.log("===============\n");
    }
}
