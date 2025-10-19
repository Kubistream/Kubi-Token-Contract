// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/TokenYield.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// Mock ERC20 sebagai underlying token
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
    address depositor = address(0x123);
    address user1 = address(0x111);
    address user2 = address(0x222);

    function setUp() public {
        // Deploy mock underlying token
        mockToken = new MockToken();

        // Deploy TokenYield
        tokenYield = new TokenYield(
            "Yield Token",
            "YLD",
            address(mockToken),
            address(0), // vault optional
            depositor
        );

        // Tambahkan saldo ke depositor
        mockToken.mint(depositor, 1000 ether);

        // Approve TokenYield agar depositor bisa transfer underlying
        vm.startPrank(depositor);
        mockToken.approve(address(tokenYield), type(uint256).max);
        vm.stopPrank();

        // Pastikan owner punya minter role
        assertTrue(tokenYield.hasRole(tokenYield.MINTER_ROLE(), owner));
    }

    function testMint() public {
        tokenYield.mint(user1, 100 ether);

        uint256 bal = tokenYield.balanceOf(user1);
        assertEq(bal, 100 ether, "balance mismatch");
    }

    function testDepositYield() public {
        vm.startPrank(depositor);
        tokenYield.depositYield(user1, 200 ether);
        vm.stopPrank();

        uint256 bal = tokenYield.balanceOf(user1);
        assertEq(bal, 200 ether, "deposit yield failed");

        uint256 contractBal = mockToken.balanceOf(address(tokenYield));
        assertEq(contractBal, 200 ether, "underlying not received");
    }

    function testRebaseIncreasesBalances() public {
        // Mint dan rebase
        tokenYield.mint(user1, 100 ether);
        uint256 beforeBal = tokenYield.balanceOf(user1);

        tokenYield.rebase(12e17); // +20%

        uint256 afterBal = tokenYield.balanceOf(user1);
        assertGt(afterBal, beforeBal, "balance should increase after rebase");
    }

    function testTransfer() public {
        tokenYield.mint(user1, 100 ether);

        vm.prank(user1);
        tokenYield.transfer(user2, 50 ether);

        assertEq(tokenYield.balanceOf(user1), 50 ether);
        assertEq(tokenYield.balanceOf(user2), 50 ether);
    }

    function testRedeem() public {
        vm.startPrank(depositor);
        tokenYield.depositYield(user1, 300 ether);
        vm.stopPrank();

        uint256 beforeUserBal = mockToken.balanceOf(user1);
        uint256 beforeContractBal = mockToken.balanceOf(address(tokenYield));

        vm.prank(user1);
        tokenYield.redeem(100 ether);

        uint256 afterUserBal = mockToken.balanceOf(user1);
        uint256 afterContractBal = mockToken.balanceOf(address(tokenYield));

        assertEq(afterUserBal - beforeUserBal, 100 ether, "user should receive underlying");
        assertEq(beforeContractBal - afterContractBal, 100 ether, "contract should decrease underlying");
    }

    function test_RevertWhen_DepositByNonDepositor() public {
        vm.expectRevert("TokenYield: only depositor contract");
        tokenYield.depositYield(user1, 100 ether);
    }


    function test_RevertWhen_MintByNonMinter() public {
        tokenYield.removeMinter(owner);

        vm.expectRevert("TokenYield: not minter");
        tokenYield.mint(user1, 100 ether);
    }


    function testUpdateVaultAndDepositor() public {
        address newVault = address(0x777);
        address newDepo = address(0x888);

        tokenYield.updateVault(newVault);
        tokenYield.updateDepositorContract(newDepo);

        assertEq(tokenYield.vault(), newVault);
        assertEq(tokenYield.depositorContract(), newDepo);
    }

    function testSimulateYield() public {
        tokenYield.mint(user1, 100 ether);
        uint256 before = tokenYield.balanceOf(user1);

        tokenYield.simulateYield(25); // +25%

        uint256 afterBal = tokenYield.balanceOf(user1);
        assertApproxEqAbs(afterBal, (before * 125) / 100, 1e12, "should grow ~25%");
    }
}
