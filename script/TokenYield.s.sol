// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {TokenYield} from "../src/TokenYield.sol";
import {console} from "forge-std/console.sol";

contract TokenYieldScript is Script {
    TokenYield public token;

    function run() external returns (address) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        token = new TokenYield("Wq ETH", "WqETH");
        console.log("Token deployed at:", address(token));
        vm.stopBroadcast();

        return (address(token));
    }
}