// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {TokenYield} from "../src/TokenYield.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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

    function testDepositYieldWithExternalVault() public {
        address vaultUser = address(0x777);
        tokenYield.updateVault(vaultUser);

        vm.startPrank(depositor);
        tokenYield.depositYield(user1, 150 ether);
        vm.stopPrank();

        assertEq(mockToken.balanceOf(vaultUser), 150 ether, "vault should receive underlying");
        assertEq(mockToken.balanceOf(address(tokenYield)), 0, "contract should not retain underlying");

        // Approve TokenYield to pull funds back from the vault for redemption
        vm.prank(vaultUser);
        mockToken.approve(address(tokenYield), type(uint256).max);

        uint256 userBefore = mockToken.balanceOf(user1);

        vm.prank(user1);
        tokenYield.redeem(50 ether);

        assertEq(mockToken.balanceOf(user1) - userBefore, 50 ether, "user should receive redeemed underlying");
        assertEq(mockToken.balanceOf(vaultUser), 100 ether, "vault balance should decrease by redeemed amount");
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

    function testRebaseUpdatesGrowthState() public {
        tokenYield.mint(user1, 100 ether);

        uint256 expectedGrowth = 5e17; // +50%
        uint256 blockBefore = block.number;
        tokenYield.rebase(15e17);

        assertApproxEqAbs(tokenYield.balanceOf(user1), 150 ether, 1, "balance should scale by 1.5x");
        assertEq(tokenYield.cumulativeGrowth(), expectedGrowth, "cumulative growth mismatch");
        assertEq(tokenYield.currentGrowth(), expectedGrowth, "current growth mismatch");
        assertEq(tokenYield.totalGrowthPercent(), expectedGrowth, "total growth mismatch");
        assertEq(tokenYield.lastScalingFactor(), 1e18, "last scaling factor should record previous value");
        assertEq(tokenYield.lastRebaseBlock(), blockBefore, "rebase block should update");
    }

    function testSimulateYieldUpdatesGrowthMetrics() public {
        tokenYield.mint(user1, 200 ether);

        uint256 expectedGrowth = 12e16; // +12%
        uint256 expectedScaling = (1e18 * (1e18 + (12 * 1e16))) / 1e18;
        uint256 blockBefore = block.number;

        tokenYield.simulateYield(12);

        assertEq(tokenYield.scalingFactor(), expectedScaling, "scaling factor mismatch");
        assertEq(tokenYield.cumulativeGrowth(), expectedGrowth, "cumulative growth mismatch");
        assertEq(tokenYield.totalGrowthPercent(), expectedGrowth, "total growth mismatch");
        assertEq(tokenYield.lastScalingFactor(), 1e18, "last scaling should capture previous factor");
        assertEq(tokenYield.lastRebaseBlock(), blockBefore, "simulate yield should update block");
        assertApproxEqAbs(tokenYield.balanceOf(user1), (200 ether * 112) / 100, 1, "balance should grow 12%");
    }

    function testResetScalingRestoresBaseState() public {
        tokenYield.mint(user1, 100 ether);
        tokenYield.rebase(15e17); // 1.5x
        assertApproxEqAbs(tokenYield.balanceOf(user1), 150 ether, 1, "balance should scale before reset");

        uint256 expectedBlock = block.number + 1;
        vm.roll(expectedBlock);
        tokenYield.resetScaling();

        assertEq(tokenYield.scalingFactor(), 1e18, "scaling factor should reset");
        assertEq(tokenYield.cumulativeGrowth(), 0, "cumulative growth should reset");
        assertEq(tokenYield.currentGrowth(), 0, "current growth should reset");
        assertEq(tokenYield.totalGrowthPercent(), 0, "total growth should reset");
        assertEq(tokenYield.balanceOf(user1), 100 ether, "balance should return to base amount");
        assertEq(tokenYield.lastScalingFactor(), 1e18, "last scaling factor should record base");
        assertEq(tokenYield.lastRebaseBlock(), expectedBlock, "reset should update block number");
    }

    function testResetScalingRevertsAtBaseState() public {
        vm.expectRevert("TokenYield: already at base");
        tokenYield.resetScaling();
    }

    function testPreviewRebaseProjectsGrowth() public {
        tokenYield.rebase(12e17); // 1.2x

        (uint256 growth, uint256 projectedCumulative) = tokenYield.previewRebase(15e17); // 1.5x

        uint256 expectedGrowth = ((15e17 * 1e18) / 12e17) - 1e18; // ~= 0.25e18
        uint256 expectedCumulative = tokenYield.cumulativeGrowth() + expectedGrowth;

        assertEq(growth, expectedGrowth, "preview growth mismatch");
        assertEq(projectedCumulative, expectedCumulative, "preview cumulative mismatch");
    }

    function testPreviewRebaseWhenNonIncreasingFactor() public {
        tokenYield.rebase(15e17); // growth tracked
        uint256 existingGrowth = tokenYield.cumulativeGrowth();

        (uint256 growth, uint256 projectedCumulative) = tokenYield.previewRebase(1e18); // no increase

        assertEq(growth, 0, "growth should be zero when factor does not increase");
        assertEq(projectedCumulative, existingGrowth, "cumulative growth should remain unchanged");
    }

    function testPreviewGrowthUsingPpm() public {
        uint256 growthPpm = 186; // 0.0186%
        (uint256 newFactor, uint256 growth, uint256 projectedCumulative) = tokenYield.previewGrowth(growthPpm);

        uint256 expectedFactor = (1e18 * (1_000_000 + growthPpm)) / 1_000_000;
        uint256 expectedGrowth = expectedFactor - 1e18;

        assertEq(newFactor, expectedFactor, "ppm preview new factor mismatch");
        assertEq(growth, expectedGrowth, "ppm preview growth mismatch");
        assertEq(projectedCumulative, expectedGrowth, "ppm preview cumulative mismatch");
    }

    function testBurnReducesInternalBalance() public {
        tokenYield.mint(user1, 200 ether);
        assertEq(tokenYield.internalBalanceOf(user1), 200 ether, "precondition failed");

        tokenYield.burn(user1, 50 ether);

        assertEq(tokenYield.internalBalanceOf(user1), 150 ether, "internal balance should reduce");
        assertEq(tokenYield.balanceOf(user1), 150 ether, "external balance should reduce");
    }

    function testBurnRevertsWhenInsufficientBalance() public {
        vm.expectRevert("TokenYield: insufficient");
        tokenYield.burn(user1, 1 ether);
    }

    function testTransferFromUsesAllowance() public {
        tokenYield.mint(user1, 100 ether);

        vm.prank(user1);
        tokenYield.approve(user2, 70 ether);

        vm.prank(user2);
        tokenYield.transferFrom(user1, user2, 70 ether);

        assertEq(tokenYield.balanceOf(user1), 30 ether, "sender balance incorrect");
        assertEq(tokenYield.balanceOf(user2), 70 ether, "recipient balance incorrect");
        assertEq(tokenYield.allowance(user1, user2), 0, "allowance should be consumed");
    }

    function testWalletGrowthReflectsScaling() public {
        tokenYield.mint(user1, 100 ether);
        tokenYield.rebase(12e17); // +20%

        assertEq(tokenYield.walletGrowth(user1), 2e17, "wallet growth should reflect scaling");
    }

    function testRedeemRevertsInvalidAmount() public {
        vm.expectRevert("TokenYield: invalid amount");
        vm.prank(user1);
        tokenYield.redeem(0);
    }

    function testDepositYieldRevertsZeroAmount() public {
        vm.startPrank(depositor);
        vm.expectRevert("TokenYield: invalid amount");
        tokenYield.depositYield(user1, 0);
        vm.stopPrank();
    }

    function testRebaseRevertsOnZeroScaling() public {
        vm.expectRevert("TokenYield: invalid scaling");
        tokenYield.rebase(0);
    }
}
