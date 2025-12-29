// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFT is ERC721 {

    address public owner;
    uint256 public tokenId;

    event Mint(address indexed to, uint256 tokenId);

    error Unauthorized();

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        owner = msg.sender;
    }

    function mint(address to) external onlyOwner {
        tokenId++;
        _mint(to, tokenId);

        emit Mint(to, tokenId);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }
}