// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Token} from "../src/Token.sol";
import {console} from "forge-std/console.sol";

contract DeployMultipleTokensScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        string[10] memory names = [
            "USDC Kubi", "USDT Kubi", "IDRX Kubi", "ASTER Kubi", "MANTA Kubi",
            "Bitcoin Kubi", "ETH Kubi", "PENGU Kubi", "LUNA Kubi", "BNB Kubi"
        ];
        string[10] memory symbols = [
            "USDCkb", "USDTkb", "IDRXkb", "ASTERkb", "MANTAkb",
            "Bitcoinkb", "ETHkb", "PENGUkb", "LUNAkb", "BNBkb"
        ];

        // Deploy 10 token
        for (uint256 i = 0; i < 10; i++) {
            Token token = new Token(names[i], symbols[i]);
            console.log("Deployed:", names[i], "at", address(token));
        }

        vm.stopBroadcast();
    }
}
