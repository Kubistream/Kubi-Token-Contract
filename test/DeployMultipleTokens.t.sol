// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DeployMultipleTokensScript} from "../script/DeployMultipleTokens.s.sol";
import {Token} from "../src/Token.sol";

contract DeployMultipleTokensTest is Test {
    DeployMultipleTokensScript deployScript;

    function setUp() public {
        deployScript = new DeployMultipleTokensScript();
    }

    function testDeployMultipleTokens() public {
        vm.startPrank(address(this)); // simulasi sebagai deployer

        string[10] memory names = [
            "USDC Kubi", "USDT Kubi", "IDRX Kubi", "ASTER Kubi", "MANTA Kubi",
            "Bitcoin Kubi", "ETH Kubi", "PENGU Kubi", "LUNA Kubi", "BNB Kubi"
        ];
        string[10] memory symbols = [
            "USDCkb", "USDTkb", "IDRXkb", "ASTERkb", "MANTAkb",
            "Bitcoinkb", "ETHkb", "PENGUkb", "LUNAkb", "BNBkb"
        ];

        for (uint256 i = 0; i < 10; i++) {
            Token token = new Token(names[i], symbols[i]);
            
            // Logging ke konsol
            console.log("==== Token deployed ====");
            console.log("  Name   :", names[i]);
            console.log("  Symbol :", symbols[i]);
            console.log("  Address:", address(token));
            console.log("----------------------------");

            // Assertion
            assertEq(token.name(), names[i], "Name mismatch");
            assertEq(token.symbol(), symbols[i], "Symbol mismatch");
            assertEq(token.totalSupply(), 0, "Initial supply should be zero");
        }

        vm.stopPrank();
    }
}
