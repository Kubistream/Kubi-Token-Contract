// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TokenYield} from "../src/TokenYield.sol";

contract DeployMultipleTokenYieldsScript is Script {
    struct TokenInfo {
        string name;
        string symbol;
        string envPrefix;
    }

    struct Protocol {
        string name;
        string envPrefix;
        TokenInfo[] tokens;
    }

    error MissingAddress(string key);

    function run() external returns (TokenYield[] memory deployedTokens) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        // Load protocol/token definitions
        Protocol[] memory protocols = _buildProtocols();
        uint256 totalTokens = _countTokens(protocols);
        deployedTokens = new TokenYield[](totalTokens);

        // Defaults (can be overridden per token via env)
        address defaultUnderlying = vm.envOr("DEFAULT_UNDERLYING_TOKEN", address(0));
        address defaultVault = vm.envOr("DEFAULT_VAULT_ADDRESS", address(0));
        address defaultDepositor = vm.envOr("DEFAULT_DEPOSITOR_CONTRACT", address(0));

        vm.startBroadcast(privateKey);

        uint256 deployedIndex = 0;
        for (uint256 i = 0; i < protocols.length; i++) {
            deployedIndex = _deployProtocol(
                protocols[i],
                defaultUnderlying,
                defaultVault,
                defaultDepositor,
                deployedTokens,
                deployedIndex
            );
        }

        vm.stopBroadcast();

        return deployedTokens;
    }

    function _countTokens(Protocol[] memory protocols) internal pure returns (uint256 total) {
        for (uint256 i = 0; i < protocols.length; i++) {
            total += protocols[i].tokens.length;
        }
    }

    function _requireUnderlying(string memory key, address fallbackValue) internal view returns (address value) {
        value = vm.envOr(key, fallbackValue);
        if (value == address(0)) {
            revert MissingAddress(key);
        }
    }

    function _addressWithFallback(string memory key, address fallbackValue) internal view returns (address) {
        return vm.envOr(key, fallbackValue);
    }

    function _buildProtocols() internal pure returns (Protocol[] memory protocols) {
        protocols = new Protocol[](4);

        protocols[0].name = "Morpho";
        protocols[0].envPrefix = "MORPHO";
        protocols[0].tokens = new TokenInfo[](5);
        protocols[0].tokens[0] = TokenInfo("Morpho Staked USDC", "moUSDC", "MORPHO_USDC");
        protocols[0].tokens[1] = TokenInfo("Morpho Staked USDT", "moUSDT", "MORPHO_USDT");
        protocols[0].tokens[2] = TokenInfo("Morpho Staked IDRX", "moIDRX", "MORPHO_IDRX");
        protocols[0].tokens[3] = TokenInfo("Morpho Staked BTC", "moBTC", "MORPHO_BTC");
        protocols[0].tokens[4] = TokenInfo("Morpho Staked ETH", "moETH", "MORPHO_ETH");

        protocols[1].name = "Aero";
        protocols[1].envPrefix = "AERO";
        protocols[1].tokens = new TokenInfo[](5);
        protocols[1].tokens[0] = TokenInfo("Aero Staked USDC", "aeUSDC", "AERO_USDC");
        protocols[1].tokens[1] = TokenInfo("Aero Staked USDT", "aeUSDT", "AERO_USDT");
        protocols[1].tokens[2] = TokenInfo("Aero Staked IDRX", "aeIDRX", "AERO_IDRX");
        protocols[1].tokens[3] = TokenInfo("Aero Staked BTC", "aeBTC", "AERO_BTC");
        protocols[1].tokens[4] = TokenInfo("Aero Staked ETH", "aeETH", "AERO_ETH");

        protocols[2].name = "Aave";
        protocols[2].envPrefix = "AAVE";
        protocols[2].tokens = new TokenInfo[](5);
        protocols[2].tokens[0] = TokenInfo("Aave Staked USDC", "aaUSDC", "AAVE_USDC");
        protocols[2].tokens[1] = TokenInfo("Aave Staked USDT", "aaUSDT", "AAVE_USDT");
        protocols[2].tokens[2] = TokenInfo("Aave Staked IDRX", "aaIDRX", "AAVE_IDRX");
        protocols[2].tokens[3] = TokenInfo("Aave Staked BTC", "aaBTC", "AAVE_BTC");
        protocols[2].tokens[4] = TokenInfo("Aave Staked ETH", "aaETH", "AAVE_ETH");

        protocols[3].name = "Compound";
        protocols[3].envPrefix = "COMPOUND";
        protocols[3].tokens = new TokenInfo[](5);
        protocols[3].tokens[0] = TokenInfo("Compound Staked USDC", "coUSDC", "COMPOUND_USDC");
        protocols[3].tokens[1] = TokenInfo("Compound Staked USDT", "coUSDT", "COMPOUND_USDT");
        protocols[3].tokens[2] = TokenInfo("Compound Staked IDRX", "coIDRX", "COMPOUND_IDRX");
        protocols[3].tokens[3] = TokenInfo("Compound Staked BTC", "coBTC", "COMPOUND_BTC");
        protocols[3].tokens[4] = TokenInfo("Compound Staked ETH", "coETH", "COMPOUND_ETH");
    }

    function _deployProtocol(
        Protocol memory protocol,
        address defaultUnderlying,
        address defaultVault,
        address defaultDepositor,
        TokenYield[] memory deployedTokens,
        uint256 startIndex
    ) internal returns (uint256 nextIndex) {
        console.log("=== Deploying for protocol:", protocol.name);

        address protocolUnderlying = _addressWithFallback(
            string.concat(protocol.envPrefix, "_DEFAULT_UNDERLYING"),
            defaultUnderlying
        );
        address protocolVault = _addressWithFallback(
            string.concat(protocol.envPrefix, "_DEFAULT_VAULT"),
            defaultVault
        );
        address protocolDepositor = _addressWithFallback(
            string.concat(protocol.envPrefix, "_DEFAULT_DEPOSITOR"),
            defaultDepositor
        );

        uint256 deployedIndex = startIndex;
        for (uint256 i = 0; i < protocol.tokens.length; i++) {
            TokenInfo memory info = protocol.tokens[i];

            address underlying = _requireUnderlying(
                string.concat(info.envPrefix, "_UNDERLYING"),
                protocolUnderlying
            );
            address vault = protocolVault;
            address depositor = protocolDepositor;

            deployedTokens[deployedIndex] = _deployToken(
                info,
                underlying,
                vault,
                depositor
            );
            deployedIndex++;
        }

        return deployedIndex;
    }

    function _deployToken(
        TokenInfo memory info,
        address underlying,
        address vault,
        address depositor
    ) internal returns (TokenYield token) {
        token = new TokenYield(info.name, info.symbol, underlying, vault, depositor);

        console.log(
            string.concat("Deployed ", info.name, " (", info.symbol, ") at:"),
            address(token)
        );
        console.log("  Underlying:", underlying);
        console.log("  Vault:", vault);
        console.log("  Depositor:", depositor);
    }
}
