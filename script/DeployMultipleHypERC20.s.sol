// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {TokenHypERC20} from "../src/TokenHypERC20.sol";
import {Create2Factory} from "../src/Create2Factory.sol";

/// @title Deploy Multiple HypERC20 Tokens (CREATE2)
/// @notice Deploys multiple Hyperlane-enabled ERC20 tokens deterministically using CREATE2
/// @dev
/// === ENVIRONMENT VARIABLES ===
/// Required:
/// - PRIVATE_KEY: Deployer private key
/// - MAILBOX: Hyperlane Mailbox address for this chain
/// - SALT: Deployment salt (MUST BE SAME across all chains for same addresses)
///
/// Optional:
/// - INTERCHAIN_GAS_PAYMASTER: IGP address for paying gas on destination
/// - INTERCHAIN_SECURITY_MODULE: ISM address for security (default: address(0))
/// - OWNER: Token owner address (default: deployer)
/// - INITIAL_SUPPLY: Initial supply for all tokens (default: 1,000,000 tokens)
/// - FACTORY_SALT: Salt for factory deployment (default: "KUBI_FACTORY")
///
/// === USAGE ===
///
/// # Deploy on Base
/// MAILBOX=0x<BASE_MAILBOX> \
/// SALT=my-deployment-salt \
/// PRIVATE_KEY=0x... \
/// forge script script/DeployMultipleHypERC20.s.sol \
///   --rpc-url $BASE_RPC_URL \
///   --broadcast \
///   --verify \
///   -vvv
///
/// # Deploy on Mantle (USE SAME SALT!)
/// MAILBOX=0x<MANTLE_MAILBOX> \
/// SALT=my-deployment-salt \
/// PRIVATE_KEY=0x... \
/// forge script script/DeployMultipleHypERC20.s.sol \
///   --rpc-url $MANTLE_RPC_URL \
///   --broadcast \
///   --verify \
///   -vvv
///
/// === IMPORTANT ===
/// 1. Use the SAME SALT across all chains for deterministic addresses
/// 2. Factory must be deployed first (will auto-deploy if not exists)
/// 3. Tokens will have SAME ADDRESSES on all chains with same SALT
///
/// === TOKEN LIST ===
/// Deploys the following tokens:
/// - MUSDC: Kubi USD Coin
/// - MUSDT: Kubi Tether USD
/// - MNT: Kubi Mantle Token
/// - METH: Kubi Ether
/// - MPUFF: Kubi Puffer Token
/// - MAXL: Kubi Axelar Token
/// - MSVL: Kubi SSV Network Token
/// - MLINK: Kubi Chainlink Token
/// - MWBTC: Kubi Wrapped BTC
/// - MPENDLE: Kubi Pendle Token
contract DeployMultipleHypERC20 is Script {
    struct TokenConfig {
        string name;
        string symbol;
        uint8 decimals;
    }

    struct DeploymentConfig {
        address mailbox;
        address igp;
        address ism;
        address owner;
        uint256 initialSupply;
        bytes32 salt;
    }

    /// @notice Deploy all HypERC20 tokens using CREATE2
    /// @return deployedAddresses Array of deployed token addresses
    function run() external returns (address[] memory deployedAddresses) {
        // Load environment variables
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address mailbox = vm.envAddress("MAILBOX");

        // Read SALT as plain text string and convert to bytes32
        string memory saltString = vm.envString("SALT");
        bytes32 salt = keccak256(abi.encodePacked(saltString));

        address igp = vm.envOr("INTERCHAIN_GAS_PAYMASTER", address(0));
        address ism = vm.envOr("INTERCHAIN_SECURITY_MODULE", address(0));
        address owner = vm.envOr("OWNER", vm.addr(privateKey));
        uint256 initialSupply = vm.envUint("INITIAL_SUPPLY");
        bytes32 factorySalt = bytes32(vm.envOr("FACTORY_SALT", bytes32("KUBI_FACTORY")));

        // Validate required variables
        require(mailbox != address(0), "MAILBOX not set");
        require(owner != address(0), "OWNER not set");
        require(bytes(saltString).length > 0, "SALT not set");

        console.log("\n=== DEPLOYMENT CONFIGURATION ===");
        console.log("Salt string:", saltString);
        console.log("Salt (bytes32):");
        console.logBytes32(salt);
        console.log("===================================\n");

        // Deploy or get CREATE2 Factory
        Create2Factory factory;
        address factoryAddress;

        // Calculate factory address using Forge's CREATE2 deployer
        // Forge's CREATE2 deployer address is constant: 0x4e59b44847b379578588920cA78FbF26c0B4956C
        address forgeCreate2Deployer = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        bytes memory factoryBytecode = type(Create2Factory).creationCode;
        factoryAddress = address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            forgeCreate2Deployer,
            factorySalt,
            keccak256(factoryBytecode)
        )))));

        // Check if factory already exists BEFORE broadcast
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(factoryAddress)
        }

        if (codeSize > 0) {
            factory = Create2Factory(factoryAddress);
            console.log("Using existing CREATE2 Factory at:");
            console.logAddress(factoryAddress);
            console.log("");
        } else {
            vm.startBroadcast(privateKey);
            // Deploy factory using Forge's CREATE2
            factory = new Create2Factory{salt: factorySalt}();
            console.log("Deployed CREATE2 Factory at:");
            console.logAddress(address(factory));
            console.log("");
            vm.stopBroadcast();
        }

        // Define tokens to deploy
        TokenConfig[] memory tokens = new TokenConfig[](10);
        tokens[0] = TokenConfig("Mock USD Coin", "MUSDC", 18);
        tokens[1] = TokenConfig("Mock Tether USD", "MUSDT", 18);
        tokens[2] = TokenConfig("Mock Mantle Token", "MNT", 18);
        tokens[3] = TokenConfig("Mock Ether", "METH", 18);
        tokens[4] = TokenConfig("Mock Puffer Token", "MPUFF", 18);
        tokens[5] = TokenConfig("Mock Axelar Token", "MAXL", 18);
        tokens[6] = TokenConfig("Mock SSV Network Token", "MSVL", 18);
        tokens[7] = TokenConfig("Mock Chainlink Token", "MLINK", 18);
        tokens[8] = TokenConfig("Mock Wrapped BTC", "MWBTC", 8);
        tokens[9] = TokenConfig("Mock Pendle Token", "MPENDLE", 18);

        // Deploy tokens using CREATE2
        deployedAddresses = new address[](tokens.length);

        // Prepare deployment config
        DeploymentConfig memory deployCfg = DeploymentConfig({
            mailbox: mailbox,
            igp: igp,
            ism: ism,
            owner: owner,
            initialSupply: initialSupply,
            salt: salt
        });

        // Prepare bytecode (reuse across loop)
        bytes memory tokenBytecode = type(TokenHypERC20).creationCode;

        // Start broadcast for token deployments
        vm.startBroadcast(privateKey);

        for (uint256 i = 0; i < tokens.length; i++) {
            deployedAddresses[i] = _deployToken(
                factory,
                tokens[i],
                tokenBytecode,
                deployCfg
            );
        }

        vm.stopBroadcast();

        // Print summary
        _printSummary(deployedAddresses, tokens);
    }

    /// @notice Deploy a single token using CREATE2
    function _deployToken(
        Create2Factory factory,
        TokenConfig memory config,
        bytes memory tokenBytecode,
        DeploymentConfig memory deployCfg
    ) private returns (address deployedAddress) {
        // Encode constructor arguments
        bytes memory constructorArgs = abi.encode(
            deployCfg.mailbox,
            config.decimals,
            config.name,
            config.symbol,
            deployCfg.igp,
            deployCfg.ism,
            deployCfg.owner,
            deployCfg.initialSupply
        );

        // Create unique salt for each token (based on symbol + deployment salt)
        bytes32 tokenSalt = keccak256(abi.encodePacked(config.symbol, deployCfg.salt));

        // Predict address
        address predictedAddress = factory.getAddressWithArgs(
            tokenBytecode,
            tokenSalt,
            constructorArgs
        );

        // Check if token already exists
        uint256 tokenCodeSize;
        assembly {
            tokenCodeSize := extcodesize(predictedAddress)
        }

        if (tokenCodeSize > 0) {
            deployedAddress = predictedAddress;
            console.log(string(abi.encodePacked("Token ", config.symbol, " already exists at:")));
            console.logAddress(predictedAddress);
        } else {
            // Deploy using CREATE2
            deployedAddress = factory.deployWithArgs(
                tokenBytecode,
                tokenSalt,
                constructorArgs
            );

            console.log(string(abi.encodePacked("Deployed ", config.symbol, " at:")));
            console.logAddress(deployedAddress);
        }

        // Verify address matches prediction
        require(
            deployedAddress == predictedAddress,
            string(abi.encodePacked("Address mismatch for ", config.symbol))
        );
    }

    /// @notice Compute factory deployment address
    function _computeFactoryAddress(bytes32 factorySalt, uint256 privateKey) internal pure returns (address) {
        bytes memory factoryBytecode = type(Create2Factory).creationCode;
        address deployer = vm.addr(privateKey);

        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            deployer,
            factorySalt,
            keccak256(factoryBytecode)
        )))));
    }

    /// @notice Print deployment summary
    function _printSummary(
        address[] memory addresses,
        TokenConfig[] memory configs
    ) internal view {
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Total Tokens Deployed:", addresses.length);

        for (uint256 i = 0; i < addresses.length; i++) {
            console.log(string(abi.encodePacked(
                configs[i].symbol,
                ": ",
                toHexString(addresses[i])
            )));
        }
        console.log("========================\n");
        console.log("[OK] These addresses will be SAME across all chains using same SALT");
    }

    /// @notice Convert address to hex string with 0x prefix
    function toHexString(address addr) internal pure returns (string memory) {
        return string(abi.encodePacked("0x", _toHex(uint160(addr))));
    }

    /// @notice Convert uint to hex string
    function _toHex(uint160 value) internal pure returns (bytes memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory result = new bytes(40);

        for (uint256 i = 0; i < 20; i++) {
            uint256 byteValue = (value >> (152 - 8 * i)) & 0xff;
            result[i * 2] = alphabet[byteValue >> 4];
            result[i * 2 + 1] = alphabet[byteValue & 0x0f];
        }

        return result;
    }
}
