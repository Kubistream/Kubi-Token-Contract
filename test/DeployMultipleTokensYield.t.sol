// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TokenYield} from "../src/TokenYield.sol";

contract DeployMultipleProtocolsTest is Test {
    // function testSimulateDeployment() public {
    //     // jalankan bagian logiknya tanpa broadcast
    //     vm.startPrank(address(this));

    //     // Simulasi sederhana: deploy satu protokol
    //     TokenYield token = new TokenYield("AqLend Staked USDC", "aUSDC");
    //     console.log("Simulated token deployed:", address(token));

    //     assertEq(token.name(), "AqLend Staked USDC");
    //     assertEq(token.symbol(), "aUSDC");

    //     vm.stopPrank();
    // }
}
