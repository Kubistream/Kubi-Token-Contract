// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Token} from "./Token.sol";

contract Factory {
    event TokenCreated(address tokenAddress, string name, string symbol);

    function createToken(string memory name, string memory symbol) external returns (address){
        Token token = new Token(name, symbol);

        emit TokenCreated(address(token), name, symbol);
        return address(token);
    }
}
