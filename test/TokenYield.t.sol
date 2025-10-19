// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/TokenYield.sol";

contract TokenYieldTest is Test {
    TokenYield token;

    address owner = address(this);
    address minter = address(0xBEEF);
    address user = address(0xCAFE);

    function setUp() public {
        token = new TokenYield("Yield Token", "YLD");
        // owner otomatis punya DEFAULT_ADMIN_ROLE dan MINTER_ROLE
    }

    function testInitialSetup() public view {
        assertEq(token.name(), "Yield Token");
        assertEq(token.symbol(), "YLD");
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(token.hasRole(token.MINTER_ROLE(), owner));
    }

    function testOwnerCanMint() public {
        token.mint(user, 100 ether);
        uint256 bal = token.balanceOf(user);
        assertEq(bal, 100 ether);
    }

    function testNonMinterCannotMint() public {
        vm.expectRevert("TokenYield: not minter");
        vm.prank(minter);
        token.mint(user, 50 ether);
    }

    function testAddMinterThenMint() public {
        token.addMinter(minter);
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));

        vm.prank(minter);
        token.mint(user, 200 ether);

        uint256 bal = token.balanceOf(user);
        assertEq(bal, 200 ether);
    }

    function testRemoveMinter() public {
        token.addMinter(minter);
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));

        token.removeMinter(minter);
        assertFalse(token.hasRole(token.MINTER_ROLE(), minter));

        vm.expectRevert("TokenYield: not minter");
        vm.prank(minter);
        token.mint(user, 50 ether);
    }

    function testRebaseIncreasesBalance() public {
        token.mint(user, 100 ether);
        uint256 beforeBal = token.balanceOf(user);

        // simulate yield +10%
        token.simulateYield(10);
        uint256 afterBal = token.balanceOf(user);

        assertGt(afterBal, beforeBal);
        uint256 expected = (beforeBal * 110) / 100; // +10%
        assertApproxEqAbs(afterBal, expected, 1e10);
    }

    function testBurnReducesInternalBalance() public {
        token.mint(user, 100 ether);
        uint256 before = token.balanceOf(user);

        token.burn(user, 50 ether);
        uint256 afterBal = token.balanceOf(user);

        assertLt(afterBal, before);
        assertApproxEqAbs(afterBal, 50 ether, 1e10);
    }

    function testWalletGrowthCalculation() public {
        token.mint(user, 100 ether);
        uint256 growthBefore = token.walletGrowth(user);
        assertEq(growthBefore, 0);

        token.simulateYield(5);
        uint256 growthAfter = token.walletGrowth(user);

        // 5% growth → 0.05 * 1e18 = 5e16
        assertApproxEqAbs(growthAfter, 5e16, 1e10);
    }
}
