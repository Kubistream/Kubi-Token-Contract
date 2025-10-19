// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TokenYield} from "../src/TokenYield.sol";

contract DeployTokenYieldScript is Script {
    function run() external returns (address deployedAddress) {
        // Load private key
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        // Load parameters (pakai default kalau belum ada di .env)
        string memory name = vm.envOr("TOKEN_NAME", string("Yield Token"));
        string memory symbol = vm.envOr("TOKEN_SYMBOL", string("YLD"));
        address underlying = vm.envAddress("UNDERLYING_TOKEN");
        address vault = vm.envOr("VAULT_ADDRESS", address(0));
        address depositor = vm.envAddress("DEPOSITOR_CONTRACT");

        // Start broadcast
        vm.startBroadcast(privateKey);

        TokenYield token = new TokenYield(
            name,
            symbol,
            underlying,
            vault,
            depositor
        );

        vm.stopBroadcast();

        // Log hasil deployment
        deployedAddress = address(token);
        console.log("TokenYield deployed at:", deployedAddress);
        console.logBytes32(token.MINTER_ROLE());
        console.log("Owner:", token.owner());
        console.log("Underlying:", address(token.underlyingToken()));
        console.log("Vault:", token.vault());
        console.log("DepositorContract:", token.depositorContract());

        return deployedAddress;
    }
}
