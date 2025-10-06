// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";
import {Token} from "../src/Token.sol";

contract FactoryTest is Test {
    Factory factory;

    function setUp() public {
        factory = new Factory();
    }

    function testCreateToken() public {
        address tokenAddr = factory.createToken("TestToken", "TTK");

        assertTrue(tokenAddr != address(0), "Token address should not be zero");

        Token token = Token(tokenAddr);

        assertEq(token.name(), "TestToken");
        assertEq(token.symbol(), "TTK");

        console2.log("Token created at:", tokenAddr);
        console2.log("Name:", token.name());
        console2.log("Symbol:", token.symbol());
    }
}
