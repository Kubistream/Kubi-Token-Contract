// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Common.sol";
import "./TokenProfileScript.sol";
import {TokenHypERC20} from "../../src/TokenHypERC20.sol";

/// @notice Deploy TokenHypERC20 deterministically using EIP-2470.
contract DeployTokenHypERC20 is TokenProfileScript {
    address constant EIP2470_FACTORY = 0xce0042B868300000d44A59004Da54A005ffdcf9f;

    struct TokenConfig {
        uint8 decimals;
        string name;
        string symbol;
        address interchainGasPaymaster;
        address ism;
        uint256 initialSupply;
    }

    function _initCode(address mailbox, address owner_, TokenConfig memory cfg)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            type(TokenHypERC20).creationCode,
            abi.encode(
                mailbox,
                cfg.decimals,
                cfg.name,
                cfg.symbol,
                cfg.interchainGasPaymaster,
                cfg.ism,
                owner_,
                cfg.initialSupply
            )
        );
    }

    function _predict(bytes32 salt, bytes32 initCodeHash) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), EIP2470_FACTORY, salt, initCodeHash)))));
    }

    function run() external {
        string memory profile = _activeProfile();
        console2.log("Using token profile:", profile);

        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        // Default salt string if not provided
        string memory saltString = vm.envOr("SALT_STRING", string("HYPERLANE_WORKFLOW_TOKEN"));
        bytes32 salt = keccak256(bytes(saltString));
        address mailbox = vm.envAddress("MAILBOX");

        // Token configuration
        TokenConfig memory cfg = TokenConfig({
            decimals: uint8(_profileUint(profile, "DECIMALS", "TOKEN_DECIMALS", 18)),
            name: _profileString(profile, "NAME", "TOKEN_NAME", "Workflow Token"),
            symbol: _profileString(profile, "SYMBOL", "TOKEN_SYMBOL", "WFT"),
            interchainGasPaymaster: _interchainGasPaymasterFor(profile),
            ism: _profileAddress(profile, "ISM", "ISM", address(0)),
            initialSupply: _profileUint(profile, "TOTAL_SUPPLY", "TOTAL_SUPPLY", 1_000_000 ether)
        });

        bytes memory initCode = _initCode(mailbox, deployer, cfg);
        bytes32 initCodeHash = keccak256(initCode);
        address predicted = _predict(salt, initCodeHash);

        console2.log("TOKEN PROFILE:", profile);
        console2.log("Token (name / symbol / decimals):", cfg.name, cfg.symbol, cfg.decimals);
        console2.log("Initial supply:", cfg.initialSupply);
        console2.log("EIP-2470 factory:", EIP2470_FACTORY);
        console2.log("Mailbox:", mailbox);
        console2.logBytes32(salt);
        console2.log("Predicted token address:", predicted);

        // Avoid broadcasting a CREATE2 deploy if the contract is already deployed at the predicted address.
        // This prevents gas estimation issues (and "exceeds block gas limit") when CREATE2 would fail.
        if (predicted.code.length > 0) {
            console2.log("Token already deployed at predicted address:", predicted);
            console2.log("Token Address:", predicted);
            _logProfileEnvHints(profile, predicted);
            return;
        }

        vm.startBroadcast(pk);

        // Deploy via singleton factory
        address deployed = ISingletonFactory(EIP2470_FACTORY).deploy(initCode, salt);

        if (deployed == address(0)) {
            console2.log("Token already deployed (or deployment failed). Using predicted:", predicted);
            deployed = predicted;
        } else {
            console2.log("Token deployed successfully via factory:", deployed);
        }

        vm.stopBroadcast();

        TokenHypERC20 token = TokenHypERC20(deployed);
        address tokenAddr = address(token);

        console2.log("Token Address:", tokenAddr);

        _logProfileEnvHints(profile, tokenAddr);
    }

    function _logProfileEnvHints(string memory profile, address tokenAddr) internal view {
        console2.log("");
        console2.log("Environment variables to update:");

        string memory tokenEnvKey = string.concat("TOKEN_ADDRESS_", profile);
        console2.log(tokenEnvKey, tokenAddr);
    }

    function _interchainGasPaymasterFor(string memory profile) internal view returns (address) {
        address igp = _profileAddress(profile, "IGP", "INTERCHAIN_GAS_PAYMASTER", address(0));
        if (igp != address(0)) {
            return igp;
        }
        // Backward compatibility: fall back to HOOK env vars if IGP is missing.
        return _profileAddress(profile, "HOOK", "HOOK", address(0));
    }
}
