// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Token} from "../src/Token.sol";
import {console} from "forge-std/console.sol";

contract DeployMultipleTokensScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        string[5] memory names = [
            "ZORA Kubi",
            "AAVE Kubi",
            "NOICE Kubi",
            "EGGS Kubi",
            "AERO Kubi"
        ];

        string[5] memory symbols = [
            "ZORAkb",
            "AAVEkb",
            "NOICEkb",
            "EGGS kb",
            "AEROkb"
        ];

        // Deploy 10 token
        for (uint256 i = 0; i < 5; i++) {
            Token token = new Token(names[i], symbols[i]);
            console.log("Deployed:", names[i], "at", address(token));
        }

        vm.stopBroadcast();
    }
}
