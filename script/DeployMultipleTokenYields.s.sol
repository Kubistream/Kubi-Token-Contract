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

        protocols[0].name = "Minterest";
        protocols[0].envPrefix = "MINTEREST";
        protocols[0].tokens = new TokenInfo[](5);
        protocols[0].tokens[0] = TokenInfo("Minterest Staked USDC", "miUSDC", "MINTEREST_USDC");
        protocols[0].tokens[1] = TokenInfo("Minterest Staked USDT", "miUSDT", "MINTEREST_USDT");
        protocols[0].tokens[2] = TokenInfo("Minterest Staked MNT", "miMNT", "MINTEREST_MNT");
        protocols[0].tokens[3] = TokenInfo("Minterest Staked BTC", "miBTC", "MINTEREST_BTC");
        protocols[0].tokens[4] = TokenInfo("Minterest Staked ETH", "miETH", "MINTEREST_ETH");

        protocols[1].name = "Lendle";
        protocols[1].envPrefix = "LENDLE";
        protocols[1].tokens = new TokenInfo[](5);
        protocols[1].tokens[0] = TokenInfo("Lendle Staked USDC", "leUSDC", "LENDLE_USDC");
        protocols[1].tokens[1] = TokenInfo("Lendle Staked USDT", "leUSDT", "LENDLE_USDT");
        protocols[1].tokens[2] = TokenInfo("Lendle Staked MNT", "leMNT", "LENDLE_MNT");
        protocols[1].tokens[3] = TokenInfo("Lendle Staked BTC", "leBTC", "LENDLE_BTC");
        protocols[1].tokens[4] = TokenInfo("Lendle Staked ETH", "leETH", "LENDLE_ETH");

        protocols[2].name = "INIT Capital";
        protocols[2].envPrefix = "INIT_CAPITAL";
        protocols[2].tokens = new TokenInfo[](5);
        protocols[2].tokens[0] = TokenInfo("INIT Capital Staked USDC", "icUSDC", "INIT_CAPITAL_USDC");
        protocols[2].tokens[1] = TokenInfo("INIT Capital Staked USDT", "icUSDT", "INIT_CAPITAL_USDT");
        protocols[2].tokens[2] = TokenInfo("INIT Capital Staked MNT", "icMNT", "INIT_CAPITAL_MNT");
        protocols[2].tokens[3] = TokenInfo("INIT Capital Staked BTC", "icBTC", "INIT_CAPITAL_BTC");
        protocols[2].tokens[4] = TokenInfo("INIT Capital Staked ETH", "icETH", "INIT_CAPITAL_ETH");

        protocols[3].name = "Compound";
        protocols[3].envPrefix = "COMPOUND";
        protocols[3].tokens = new TokenInfo[](5);
        protocols[3].tokens[0] = TokenInfo("Compound Staked USDC", "coUSDC", "COMPOUND_USDC");
        protocols[3].tokens[1] = TokenInfo("Compound Staked USDT", "coUSDT", "COMPOUND_USDT");
        protocols[3].tokens[2] = TokenInfo("Compound Staked MNT", "coMNT", "COMPOUND_MNT");
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
