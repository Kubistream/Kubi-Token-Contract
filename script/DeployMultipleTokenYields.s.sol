// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {TokenYield} from "../src/TokenYield.sol";
import {console} from "forge-std/console.sol";

contract DeployMultipleTokenYieldsScript is Script {
    struct TokenInfo {
        string name;
        string symbol;
    }

    struct Protocol {
        string name;
        TokenInfo[] tokens;
    }

    // function run() external {
    //     uint256 privateKey = vm.envUint("PRIVATE_KEY");
    //     vm.startBroadcast(privateKey);

    //     // === Define protocols ===
    //     Protocol[] memory protocols = new Protocol[](3);

    //     // --- AqLend ---
    //     protocols[0].name = "AqLend";
    //     protocols[0].tokens = new TokenInfo[](6);
    //     protocols[0].tokens[0] = TokenInfo("AqLend Staked USDC", "aUSDC");
    //     protocols[0].tokens[1] = TokenInfo("AqLend Staked USDT", "aUSDT");
    //     protocols[0].tokens[2] = TokenInfo("AqLend Staked IDRX", "aIDRX");
    //     protocols[0].tokens[3] = TokenInfo("AqLend Staked BTC", "aBTC");
    //     protocols[0].tokens[4] = TokenInfo("AqLend Staked ETH", "aETH");

    //     // --- BqLend ---
    //     protocols[1].name = "BqLend";
    //     protocols[1].tokens = new TokenInfo[](6);
    //     protocols[1].tokens[0] = TokenInfo("BqLend Staked USDC", "bUSDC");
    //     protocols[1].tokens[1] = TokenInfo("BqLend Staked USDT", "bUSDT");
    //     protocols[1].tokens[2] = TokenInfo("BqLend Staked IDRX", "bIDRX");
    //     protocols[1].tokens[3] = TokenInfo("BqLend Staked BTC", "bBTC");
    //     protocols[1].tokens[4] = TokenInfo("BqLend Staked ETH", "bETH");

    //     // --- CqLend ---
    //     protocols[2].name = "CqLend";
    //     protocols[2].tokens = new TokenInfo[](6);
    //     protocols[2].tokens[0] = TokenInfo("CqLend Staked USDC", "cUSDC");
    //     protocols[2].tokens[1] = TokenInfo("CqLend Staked USDT", "cUSDT");
    //     protocols[2].tokens[2] = TokenInfo("CqLend Staked IDRX", "cIDRX");
    //     protocols[2].tokens[3] = TokenInfo("CqLend Staked BTC", "cBTC");
    //     protocols[2].tokens[4] = TokenInfo("CqLend Staked ETH", "cETH");

    //     // === Deploy all tokens ===
    //     for (uint256 i = 0; i < protocols.length; i++) {
    //         console.log("=== Deploying for protocol:", protocols[i].name);
    //         for (uint256 j = 0; j < protocols[i].tokens.length; j++) {
    //             TokenInfo memory tokenInfo = protocols[i].tokens[j];
    //             TokenYield token = new TokenYield(tokenInfo.name, tokenInfo.symbol);
    //             console.log(
    //                 string.concat("Deployed ", tokenInfo.name, " (", tokenInfo.symbol, ") at:"),
    //                 address(token)
    //             );
    //         }
    //     }

    //     vm.stopBroadcast();
    // }
}
