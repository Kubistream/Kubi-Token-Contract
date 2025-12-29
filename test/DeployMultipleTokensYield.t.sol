// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {DeployMultipleTokenYieldsScript} from "../script/DeployMultipleTokenYields.s.sol";
import {TokenYield} from "../src/TokenYield.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract DeployMultipleTokenYieldsScriptTest is Test {
    DeployMultipleTokenYieldsScript private deployScript;
    MockToken private morphoUnderlying;
    MockToken private aeroUnderlying;
    MockToken private aaveUnderlying;
    MockToken private compoundUnderlying;

    address private deployer;
    uint256 private deployerPrivateKey;
    address private morphoVault = address(0x111);
    address private aeroVault = address(0x222);
    address private aaveVault = address(0x333);
    address private compoundVault = address(0x444);
    address private morphoDepositor = address(0xAAA);
    address private aeroDepositor = address(0xA0A);
    address private aaveDepositor = address(0xBBB);
    address private compoundDepositor = address(0xCCC);

    function setUp() public {
        deployScript = new DeployMultipleTokenYieldsScript();
        morphoUnderlying = new MockToken("Mock Morpho", "mMOR");
        aeroUnderlying = new MockToken("Mock Aero", "mAER");
        aaveUnderlying = new MockToken("Mock Aave", "mAAV");
        compoundUnderlying = new MockToken("Mock Compound", "mCOM");

        // Use deterministic broadcaster so expected owner matches
        deployerPrivateKey = uint256(uint160(address(this)));
        deployer = vm.addr(deployerPrivateKey);

        vm.setEnv("PRIVATE_KEY", vm.toString(deployerPrivateKey));
        vm.setEnv("DEFAULT_UNDERLYING_TOKEN", vm.toString(address(0)));
        vm.setEnv("DEFAULT_VAULT_ADDRESS", vm.toString(address(0)));
        vm.setEnv("DEFAULT_DEPOSITOR_CONTRACT", vm.toString(address(0)));

        vm.setEnv("MORPHO_DEFAULT_UNDERLYING", vm.toString(address(morphoUnderlying)));
        vm.setEnv("AERO_DEFAULT_UNDERLYING", vm.toString(address(aeroUnderlying)));
        vm.setEnv("AAVE_DEFAULT_UNDERLYING", vm.toString(address(aaveUnderlying)));
        vm.setEnv("COMPOUND_DEFAULT_UNDERLYING", vm.toString(address(compoundUnderlying)));

        vm.setEnv("MORPHO_DEFAULT_VAULT", vm.toString(morphoVault));
        vm.setEnv("AERO_DEFAULT_VAULT", vm.toString(aeroVault));
        vm.setEnv("AAVE_DEFAULT_VAULT", vm.toString(aaveVault));
        vm.setEnv("COMPOUND_DEFAULT_VAULT", vm.toString(compoundVault));

        vm.setEnv("MORPHO_DEFAULT_DEPOSITOR", vm.toString(morphoDepositor));
        vm.setEnv("AERO_DEFAULT_DEPOSITOR", vm.toString(aeroDepositor));
        vm.setEnv("AAVE_DEFAULT_DEPOSITOR", vm.toString(aaveDepositor));
        vm.setEnv("COMPOUND_DEFAULT_DEPOSITOR", vm.toString(compoundDepositor));

        _setTokenOverrides("MORPHO", morphoUnderlying, morphoDepositor);
        _setTokenOverrides("AERO", aeroUnderlying, aeroDepositor);
        _setTokenOverrides("AAVE", aaveUnderlying, aaveDepositor);
        _setTokenOverrides("COMPOUND", compoundUnderlying, compoundDepositor);
    }

    function testRunDeploysConfiguredTokenYields() public {
        TokenYield[] memory tokens = deployScript.run();
        assertEq(tokens.length, 20, "Unexpected number of deployed tokens");

        string[20] memory expectedNames = [
            "Morpho Staked USDC",
            "Morpho Staked USDT",
            "Morpho Staked IDRX",
            "Morpho Staked BTC",
            "Morpho Staked ETH",
            "Aero Staked USDC",
            "Aero Staked USDT",
            "Aero Staked IDRX",
            "Aero Staked BTC",
            "Aero Staked ETH",
            "Aave Staked USDC",
            "Aave Staked USDT",
            "Aave Staked IDRX",
            "Aave Staked BTC",
            "Aave Staked ETH",
            "Compound Staked USDC",
            "Compound Staked USDT",
            "Compound Staked IDRX",
            "Compound Staked BTC",
            "Compound Staked ETH"
        ];

        string[20] memory expectedSymbols = [
            "moUSDC",
            "moUSDT",
            "moIDRX",
            "moBTC",
            "moETH",
            "aeUSDC",
            "aeUSDT",
            "aeIDRX",
            "aeBTC",
            "aeETH",
            "aaUSDC",
            "aaUSDT",
            "aaIDRX",
            "aaBTC",
            "aaETH",
            "coUSDC",
            "coUSDT",
            "coIDRX",
            "coBTC",
            "coETH"
        ];

        address[4] memory expectedUnderlyingAddrs = [
            address(morphoUnderlying),
            address(aeroUnderlying),
            address(aaveUnderlying),
            address(compoundUnderlying)
        ];
        address[4] memory expectedVaults = [morphoVault, aeroVault, aaveVault, compoundVault];
        address[4] memory expectedDepositors = [morphoDepositor, aeroDepositor, aaveDepositor, compoundDepositor];

        for (uint256 i = 0; i < tokens.length; i++) {
            TokenYield token = tokens[i];
            uint256 protocolIndex = i / 5;

            assertEq(token.name(), expectedNames[i], "Name mismatch");
            assertEq(token.symbol(), expectedSymbols[i], "Symbol mismatch");
            assertEq(address(token.underlyingToken()), expectedUnderlyingAddrs[protocolIndex], "Underlying mismatch");
            assertEq(token.vault(), expectedVaults[protocolIndex], "Vault mismatch");
            assertEq(token.depositorContract(), expectedDepositors[protocolIndex], "Depositor mismatch");
            assertEq(token.owner(), deployer, "Owner mismatch");

            bytes32 minterRole = token.MINTER_ROLE();
            assertTrue(token.hasRole(minterRole, deployer), "Deployer should have minter role");
        }
    }

    function _setTokenOverrides(
        string memory prefix,
        MockToken underlying,
        address depositor
    ) internal {
        vm.setEnv(string.concat(prefix, "_USDC_UNDERLYING"), vm.toString(address(underlying)));
        vm.setEnv(string.concat(prefix, "_USDT_UNDERLYING"), vm.toString(address(underlying)));
        vm.setEnv(string.concat(prefix, "_IDRX_UNDERLYING"), vm.toString(address(underlying)));
        vm.setEnv(string.concat(prefix, "_BTC_UNDERLYING"), vm.toString(address(underlying)));
        vm.setEnv(string.concat(prefix, "_ETH_UNDERLYING"), vm.toString(address(underlying)));

        vm.setEnv(string.concat(prefix, "_USDC_DEPOSITOR"), vm.toString(depositor));
        vm.setEnv(string.concat(prefix, "_USDT_DEPOSITOR"), vm.toString(depositor));
        vm.setEnv(string.concat(prefix, "_IDRX_DEPOSITOR"), vm.toString(depositor));
        vm.setEnv(string.concat(prefix, "_BTC_DEPOSITOR"), vm.toString(depositor));
        vm.setEnv(string.concat(prefix, "_ETH_DEPOSITOR"), vm.toString(depositor));
    }
}
