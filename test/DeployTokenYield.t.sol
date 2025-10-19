// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TokenYield} from "../src/TokenYield.sol";

contract TokenYieldTest is Test {
    TokenYield public token;

    function setUp() public {
        // Deploy kontrak baru untuk tiap test
        token = new TokenYield("Wq ETH", "WqETH");
    }

    function testInitialValues() public view {
        // Pastikan nama dan simbol sesuai
        assertEq(token.name(), "Wq ETH");
        assertEq(token.symbol(), "WqETH");
    }

    function testMintAndBalance() public {
        address alice = address(0x1234);

        // Mint token ke Alice
        token.mint(alice, 100 ether);

        // Cek saldo
        uint256 balance = token.balanceOf(alice);
        console.log("Alice balance:", balance);
        assertEq(balance, 100 ether);
    }

    function testTransfer() public {
        address alice = address(0x1234);
        address bob = address(0x5678);

        // Pastikan kontrak ini punya izin mint
        token.mint(alice, 50 ether);
        console.log("Alice after mint:", token.balanceOf(alice));


        // Cek saldo Alice
        assertEq(token.balanceOf(alice), 50 ether, "Mint failed");

        // Jalankan transfer sebagai Alice
        vm.prank(alice);
        token.transfer(bob, 20 ether);

        assertEq(token.balanceOf(bob), 20 ether);
        assertEq(token.balanceOf(alice), 30 ether);
    }


    function testRebaseAffectsBalances() public {
        address alice = address(0x1234);
        token.mint(alice, 100e18);
        token.rebase(2e18); // simulasi yield 2x
        assertEq(token.balanceOf(alice), 200e18);
    }


}
