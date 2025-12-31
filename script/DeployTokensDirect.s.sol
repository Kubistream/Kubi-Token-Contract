// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {TokenHypERC20} from "../src/TokenHypERC20.sol";

/// @title Deploy Tokens Direct CREATE2 (No Factory)
/// @notice Deploys multiple Hyperlane ERC20 tokens using Forge's built-in CREATE2
/// @dev This script deploys tokens directly without a factory contract
///
/// === HOW IT WORKS ===
/// Each token is deployed using: new TokenHypERC20{salt: keccak256(abi.encodePacked(BASE_SALT, symbol))}(constructor_args)
///
/// === IMPORTANT ===
/// 1. Use SAME BASE_SALT across all chains for SAME addresses
/// 2. Each token gets unique salt by combining: BASE_SALT + TOKEN_SYMBOL
/// 3. Constructor args MUST be identical across chains
///
/// === USAGE ===
/// # Deploy on Base
/// SALT=kubi-token-v1 \
/// PRIVATE_KEY=0x... \
/// MAILBOX=0x... \
/// forge script script/DeployTokensDirect.s.sol \
///   --rpc-url https://base-sepolia.g.alchemy.com/v2/... \
///   --broadcast
///
/// # Deploy on Mantle (SAME SALT = SAME ADDRESSES!)
/// SALT=kubi-token-v1 \
/// PRIVATE_KEY=0x... \
/// MAILBOX=0x... \
/// forge script script/DeployTokensDirect.s.sol \
///   --rpc-url https://mantle-sepolia.g.alchemy.com/v2/... \
///   --broadcast
///
contract DeployTokensDirect is Script {
    struct TokenConfig {
        string name;
        string symbol;
        uint8 decimals;
    }

    function run() external returns (address[] memory deployedAddresses) {
        // Load environment variables
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address mailbox = vm.envAddress("MAILBOX");

        // Read BASE_SALT as plain text string
        string memory baseSalt = vm.envString("SALT");

        // Optional parameters
        address igp = vm.envOr("INTERCHAIN_GAS_PAYMASTER", address(0));
        address ism = vm.envOr("INTERCHAIN_SECURITY_MODULE", address(0));
        address owner = vm.envOr("OWNER", vm.addr(privateKey));
        uint256 initialSupply = vm.envUint("INITIAL_SUPPLY");

        console.log("\n=== DEPLOYMENT CONFIGURATION ===");
        console.log("Base salt:", baseSalt);
        console.log("Mailbox:", vm.toString(mailbox));
        console.log("Owner:", vm.toString(owner));
        console.log("Initial Supply:", initialSupply);
        console.log("===================================\n");

        vm.startBroadcast(privateKey);

        // Define tokens to deploy
        TokenConfig[] memory tokens = new TokenConfig[](10);
        tokens[0] = TokenConfig("Kubi USD Coin", "MUSDC", 18);
        tokens[1] = TokenConfig("Kubi Tether USD", "MUSDT", 18);
        tokens[2] = TokenConfig("Kubi Mantle Token", "MNT", 18);
        tokens[3] = TokenConfig("Kubi Ether", "METH", 18);
        tokens[4] = TokenConfig("Kubi Puffer Token", "MPUFF", 18);
        tokens[5] = TokenConfig("Kubi Axelar Token", "MAXL", 18);
        tokens[6] = TokenConfig("Kubi SSV Network Token", "MSVL", 18);
        tokens[7] = TokenConfig("Kubi Chainlink Token", "MLINK", 18);
        tokens[8] = TokenConfig("Kubi Wrapped BTC", "MWBTC", 8);
        tokens[9] = TokenConfig("Kubi Pendle Token", "MPENDLE", 18);

        // Deploy each token using CREATE2
        deployedAddresses = new address[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            // Create unique salt for each token: keccak256(abi.encodePacked(BASE_SALT, SYMBOL))
            bytes32 tokenSalt = keccak256(abi.encodePacked(baseSalt, tokens[i].symbol));

            // Deploy token using Forge's CREATE2
            TokenHypERC20 token = new TokenHypERC20{salt: tokenSalt}(
                mailbox,
                tokens[i].decimals,
                tokens[i].name,
                tokens[i].symbol,
                igp,
                ism,
                owner,
                initialSupply
            );

            deployedAddresses[i] = address(token);

            console.log(string(abi.encodePacked("Deployed ", tokens[i].symbol, " at:")));
            console.logAddress(address(token));
            console.log("Salt (hash of base+symbol):");
            console.logBytes32(tokenSalt);
            console.log("");
        }

        vm.stopBroadcast();

        // Print summary
        _printSummary(deployedAddresses, tokens, baseSalt);
    }

    function _printSummary(
        address[] memory addresses,
        TokenConfig[] memory tokens,
        string memory baseSalt
    ) internal view {
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Base Salt:", baseSalt);
        console.log("Total Tokens Deployed:", tokens.length);
        console.log("");

        for (uint256 i = 0; i < tokens.length; i++) {
            console.log(tokens[i].symbol, ":");
            console.logAddress(addresses[i]);
        }

        console.log("\n===============================");
        console.log("[OK] These addresses will be SAME across all chains using same BASE_SALT");
        console.log("[OK] Each token has unique salt derived from: keccak256(BASE_SALT + SYMBOL)");
        console.log("===================================\n");
    }
}
