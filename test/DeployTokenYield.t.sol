// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {DeployTokenYieldScript} from "../script/TokenYield.s.sol";
import {TokenYield} from "../src/TokenYield.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// Mock underlying token (misalnya USDC)
contract MockToken is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract TokenYieldScriptTest is Test {
    DeployTokenYieldScript public deployScript;
    TokenYield public token;
    MockToken public mockUnderlying;

    address private deployer;
    uint256 private deployerPrivateKey;
    address private depositor = address(0x123);
    address private vault = address(0x456);

    function setUp() public {
        // Derive broadcaster EOA from a deterministic private key for the test
        deployerPrivateKey = uint256(uint160(address(this)));
        deployer = vm.addr(deployerPrivateKey);

        // Deploy mock underlying token
        mockUnderlying = new MockToken();

        // Set env variables
        vm.setEnv("PRIVATE_KEY", vm.toString(deployerPrivateKey));
        vm.setEnv("TOKEN_NAME", "Yield Test Token");
        vm.setEnv("TOKEN_SYMBOL", "YTT");
        vm.setEnv("UNDERLYING_TOKEN", vm.toString(address(mockUnderlying)));
        vm.setEnv("VAULT_ADDRESS", vm.toString(vault));
        vm.setEnv("DEPOSITOR_CONTRACT", vm.toString(depositor));

        deployScript = new DeployTokenYieldScript();
    }

    function testRunDeploysTokenYield() public {
        // Jalankan script
        address deployed = deployScript.run();
        token = TokenYield(deployed);

        // Verifikasi hasil deployment
        assertEq(token.name(), "Yield Test Token", "Nama token salah");
        assertEq(token.symbol(), "YTT", "Symbol token salah");
        assertEq(address(token.underlyingToken()), address(mockUnderlying), "Underlying salah");
        assertEq(token.vault(), vault, "Vault salah");
        assertEq(token.depositorContract(), depositor, "Depositor salah");
        assertEq(token.owner(), deployer, "Owner salah");

        //  Periksa role
        bytes32 minterRole = token.MINTER_ROLE();
        assertTrue(token.hasRole(minterRole, deployer), "Deployer seharusnya minter");

        emit log_address(address(token));
        emit log_string("TokenYield deployment via script berhasil");
    }
}
