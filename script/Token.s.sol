// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Token} from "../src/Token.sol";
import {console} from "forge-std/console.sol";

contract TokenScript is Script {
    Token public token;

    function run() external returns (address) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        token = new Token("CBBTC Kubi", "CBBTCkb");
        console.log("Token deployed at:", address(token));
        vm.stopBroadcast();

        return (address(token));
    }
}