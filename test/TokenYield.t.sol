// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {TokenYield} from "../src/TokenYield.sol";
import {ERC20} from "@openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 sebagai underlying token (contoh USDC)
contract MockToken is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {
        _mint(msg.sender, 1_000_000 ether);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TokenYieldTest is Test {
    TokenYield public tokenYield;
    MockToken public mockToken;

    address owner = address(this);
    address vault = address(0xBEEF);
    address user1 = address(0x1111);
    address user2 = address(0x2222);

    function setUp() public {
        // Deploy mock underlying token
        mockToken = new MockToken();

        // Mint token ke vault untuk redeem
        mockToken.mint(vault, 1_000_000 ether);

        // Deploy TokenYield
        tokenYield = new TokenYield(
            "AqLend Staked USDC",
            "aUSDC",
            address(mockToken),
            vault
        );

        // Tambahkan MINTER_ROLE ke owner
        tokenYield.addMinter(owner);
    }

    function testMint() public {
        tokenYield.mint(user1, 100 ether);
        uint256 balance = tokenYield.balanceOf(user1);
        assertEq(balance, 100 ether, "minted balance mismatch");
    }

    function testRebaseIncreasesBalance() public {
        tokenYield.mint(user1, 100 ether);
        tokenYield.rebase(1.2e18);
        uint256 newBalance = tokenYield.balanceOf(user1);
        assertApproxEqAbs(newBalance, 120 ether, 1, "balance after rebase incorrect");
    }

    function testSimulateYield() public {
        tokenYield.mint(user1, 100 ether);
        tokenYield.simulateYield(15); // +15%
        uint256 newBalance = tokenYield.balanceOf(user1);
        assertApproxEqAbs(newBalance, 115 ether, 1, "simulate yield incorrect");
    }

    function testBurnReducesBalance() public {
        tokenYield.mint(user1, 100 ether);
        tokenYield.burn(user1, 40 ether);
        uint256 balance = tokenYield.balanceOf(user1);
        assertApproxEqAbs(balance, 60 ether, 1, "burn did not reduce balance properly");
    }

    function testUpdateVault() public {
        address newVault = address(0xCAFE);
        tokenYield.updateVault(newVault);
        assertEq(tokenYield.vault(), newVault, "vault not updated correctly");
    }

    function testRedeem() public {
        tokenYield.mint(user1, 100 ether);

        vm.startPrank(vault);
        mockToken.approve(address(tokenYield), 1_000_000 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        tokenYield.redeem(100 ether);
        vm.stopPrank();

        assertEq(mockToken.balanceOf(user1), 100 ether, "redeem underlying mismatch");
    }

    /// === FIXED: testFail → expectRevert ===

    function test_RevertWhen_RedeemWithoutEnoughBalance() public {
        vm.startPrank(user1);
        vm.expectRevert("insufficient balance");
        tokenYield.redeem(50 ether);
        vm.stopPrank();
    }

    function test_RevertWhen_UpdateVaultByNonOwner() public {
        vm.startPrank(user1);
        vm.expectRevert();
        tokenYield.updateVault(address(0xDEAD));
        vm.stopPrank();
    }

    function testTransferBetweenUsers() public {
        tokenYield.mint(user1, 200 ether);

        vm.prank(vault);
        mockToken.approve(address(tokenYield), 1_000_000 ether);

        vm.startPrank(user1);
        bool success = tokenYield.transfer(user2, 100 ether);
        vm.stopPrank();

        assertTrue(success, "transfer failed");
        assertApproxEqAbs(tokenYield.balanceOf(user2), 100 ether, 1, "receiver balance mismatch");
    }
}
