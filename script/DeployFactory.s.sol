// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {Factory} from "../src/Factory.sol";

contract DeployFactoryScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Factory factory = new Factory();
        console2.log("Factory deployed at:", address(factory));

        vm.stopBroadcast();
    }
}
