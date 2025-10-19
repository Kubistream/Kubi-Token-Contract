// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenYield is ERC20, Ownable, AccessControl {
    using SafeERC20 for IERC20;

    // ====== STORAGE ======
    mapping(address => uint256) internal _internalBalance;
    mapping(address => uint256) public userLastScaling;
    mapping(address => uint256) public userBaseBalance;

    IERC20 public underlyingToken; // token asli (misal USDC)
    address public vault;              // alamat vault (optional, tidak wajib digunakan untuk transfer)
    address public depositorContract;

    uint256 public scalingFactor = 1e18;
    uint256 public lastScalingFactor = 1e18;
    uint256 public cumulativeGrowth;
    uint256 public lastRebaseBlock;

    // ====== ROLES ======
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // ====== EVENTS ======
    event Mint(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event Rebased(uint256 oldFactor, uint256 newFactor, uint256 growthPercent);
    event ScalingReset(uint256 oldFactor, uint256 newFactor);
    event Redeemed(address indexed user, uint256 amount);
    event VaultUpdated(address indexed oldVault, address indexed newVault);
    event DepositorContractUpdated(address indexed oldContract, address indexed newContract);

    // ====== CONSTRUCTOR ======
    constructor(
        string memory name,
        string memory symbol,
        address _underlyingToken,
        address _vault,
        address _depositorContract
    ) ERC20(name, symbol) Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);

        underlyingToken = IERC20(_underlyingToken);
        vault = _vault;
        depositorContract = _depositorContract;
    }

    // ====== CORE ======
    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, msg.sender), "TokenYield: not minter");
        _;
    }

    modifier onlyDepositorContract() {
        require(msg.sender == depositorContract, "TokenYield: only depositor contract");
        _;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        require(amount > 0, "TokenYield: invalid amount");
        uint256 internalAmt = (amount * 1e18) / scalingFactor;
        _internalBalance[to] += internalAmt;

        // update user scaling/base
        userBaseBalance[to] = _internalBalance[to];
        userLastScaling[to] = scalingFactor;

        emit Mint(to, amount);
    }

    /// @notice Called by depositor contract to deposit underlying as yield and mint tokenYield for user
    function depositYield(address user, uint256 amount) external onlyDepositorContract {
        require(amount > 0, "TokenYield: invalid amount");

        // Determine where underlying should be parked: default to this contract, or an external vault when configured
        address target = vault == address(0) ? address(this) : vault;

        // Transfer underlying from depositor (msg.sender) into the target location.
        // The depositor contract must have approved this contract to pull the tokens.
        underlyingToken.safeTransferFrom(msg.sender, target, amount);

        // Calculate internal amount based on scaling factor
        uint256 internalAmt = (amount * 1e18) / scalingFactor;
        _internalBalance[user] += internalAmt;

        // Update user scaling/base
        userBaseBalance[user] = _internalBalance[user];
        userLastScaling[user] = scalingFactor;

        emit Mint(user, amount);
    }

    function balanceOf(address user) public view override returns (uint256) {
        return (_internalBalance[user] * scalingFactor) / 1e18;
    }

    function internalBalanceOf(address user) external view returns (uint256) {
        return _internalBalance[user];
    }

    // ====== REBASE / YIELD ======
    function rebase(uint256 newScalingFactor) external onlyOwner {
        require(newScalingFactor > 0, "TokenYield: invalid scaling");
        uint256 oldFactor = scalingFactor;
        scalingFactor = newScalingFactor;

        uint256 growth = 0;
        if (oldFactor > 0) {
            growth = ((scalingFactor * 1e18) / oldFactor) - 1e18;
        }

        cumulativeGrowth += growth;
        lastScalingFactor = oldFactor;
        lastRebaseBlock = block.number;

        emit Rebased(oldFactor, newScalingFactor, growth);
    }

    function simulateYield(uint256 growthPercent) external onlyOwner {
        uint256 oldFactor = scalingFactor;
        scalingFactor = (scalingFactor * (1e18 + (growthPercent * 1e16))) / 1e18;

        uint256 growth = (scalingFactor * 1e18) / oldFactor - 1e18;
        cumulativeGrowth += growth;
        lastScalingFactor = oldFactor;
        lastRebaseBlock = block.number;

        emit Rebased(oldFactor, scalingFactor, growth);
    }

    /// @notice Reset scaling factor and growth tracking back to the base state (1.0x)
    function resetScaling() external onlyOwner {
        uint256 oldFactor = scalingFactor;
        require(oldFactor != 1e18 || cumulativeGrowth != 0, "TokenYield: already at base");

        scalingFactor = 1e18;
        cumulativeGrowth = 0;
        lastScalingFactor = scalingFactor;
        lastRebaseBlock = block.number;

        emit ScalingReset(oldFactor, scalingFactor);
    }

    // ====== VIEW HELPERS ======
    function currentGrowth() public view returns (uint256) {
        if (lastScalingFactor == 0) return 0;
        return (scalingFactor * 1e18) / lastScalingFactor - 1e18;
    }

    function totalGrowthPercent() public view returns (uint256) {
        return cumulativeGrowth;
    }
    
    function walletGrowth(address user) public view returns (uint256) {
        uint256 userScale = userLastScaling[user];
        if (userScale == 0) return 0;
        uint256 ratio = (scalingFactor * 1e18) / userScale;
        if (ratio <= 1e18) return 0;
        return ratio - 1e18;
    }

    /// @notice Preview the growth and cumulative growth impact for a proposed rebase
    function previewRebase(uint256 newFactor) external view returns (uint256 growth, uint256 projectedCumulativeGrowth) {
        require(newFactor > 0, "TokenYield: invalid scaling");

        uint256 oldFactor = scalingFactor;
        projectedCumulativeGrowth = cumulativeGrowth;

        if (oldFactor > 0) {
            uint256 ratio = (newFactor * 1e18) / oldFactor;
            if (ratio > 1e18) {
                growth = ratio - 1e18;
                projectedCumulativeGrowth += growth;
            }
        }
    }

    /// @notice Preview the target scaling factor and growth when applying a growth value expressed in ppm (1 = 0.0001%)
    function previewGrowth(uint256 growthPpm) external view returns (uint256 newFactor, uint256 growth, uint256 projectedCumulativeGrowth) {
        uint256 multiplier = 1_000_000 + growthPpm; // 1e6 = 100%
        uint256 oldFactor = scalingFactor;
        projectedCumulativeGrowth = cumulativeGrowth;

        newFactor = (oldFactor * multiplier) / 1_000_000;

        if (oldFactor > 0) {
            growth = ((newFactor * 1e18) / oldFactor) - 1e18;
            projectedCumulativeGrowth += growth;
        }
    }

    function projectedBalance(address user) public view returns (uint256) {
        return (_internalBalance[user] * scalingFactor) / 1e18;
    }

    // ====== MISC ======
    function burn(address from, uint256 amount) external onlyOwner {
        require(amount > 0, "TokenYield: invalid amount");
        uint256 internalAmt = (amount * 1e18) / scalingFactor;
        require(_internalBalance[from] >= internalAmt, "TokenYield: insufficient");
        _internalBalance[from] -= internalAmt;

        // update user base/scale
        userBaseBalance[from] = _internalBalance[from];
        userLastScaling[from] = scalingFactor;

        emit Burned(from, amount);
    }

    function redeem(uint256 amount) external {
        require(amount > 0, "TokenYield: invalid amount");

        uint256 internalAmt = (amount * 1e18) / scalingFactor;
        require(_internalBalance[msg.sender] >= internalAmt, "TokenYield: insufficient balance");

        // Burn staking token (kurangi internal balance)
        _internalBalance[msg.sender] -= internalAmt;

        // update user base/scale
        userBaseBalance[msg.sender] = _internalBalance[msg.sender];
        userLastScaling[msg.sender] = scalingFactor;

        emit Burned(msg.sender, amount);

        // Transfer underlying from the appropriate source (contract or external vault) to the user
        if (vault == address(0)) {
            underlyingToken.safeTransfer(msg.sender, amount);
        } else {
            underlyingToken.safeTransferFrom(vault, msg.sender, amount);
        }

        emit Redeemed(msg.sender, amount);
    }

    /// @notice Update vault address (if kamu pakai vault eksternal)
    function updateVault(address newVault) external onlyOwner {
        require(newVault != address(0), "TokenYield: invalid vault address");
        require(newVault != vault, "TokenYield: same vault address");

        address oldVault = vault;
        vault = newVault;

        emit VaultUpdated(oldVault, newVault);
    }

    /// @notice Update depositorContract address
    function updateDepositorContract(address newDepositorContract) external onlyOwner {
        require(newDepositorContract != address(0), "TokenYield: invalid depositor address");
        require(newDepositorContract != depositorContract, "TokenYield: same depositor address");

        address oldDepositorContract = depositorContract;
        depositorContract = newDepositorContract;

        emit DepositorContractUpdated(oldDepositorContract, newDepositorContract);
    }

    // ====== ADMIN METHODS ======
    /// @notice Menambah minter baru
    function addMinter(address account) external onlyOwner {
        _grantRole(MINTER_ROLE, account);
    }

    /// @notice Menghapus minter
    function removeMinter(address account) external onlyOwner {
        _revokeRole(MINTER_ROLE, account);
    }

    // Override transfer behavior to use internal balances
    function transfer(address to, uint256 amount) public override returns (bool) {
        uint256 internalAmt = (amount * 1e18) / scalingFactor;
        require(_internalBalance[msg.sender] >= internalAmt, "TokenYield: insufficient balance");
        // optional: check underlying availability if you want
        // require(underlyingToken.balanceOf(address(this)) >= amount, "TokenYield: contract insufficient underlying");

        _internalBalance[msg.sender] -= internalAmt;
        _internalBalance[to] += internalAmt;

        // update scaling/base for both parties
        userBaseBalance[msg.sender] = _internalBalance[msg.sender];
        userLastScaling[msg.sender] = scalingFactor;

        userBaseBalance[to] = _internalBalance[to];
        userLastScaling[to] = scalingFactor;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint256 internalAmt = (amount * 1e18) / scalingFactor;
        require(_internalBalance[from] >= internalAmt, "TokenYield: insufficient balance");

        _spendAllowance(from, msg.sender, amount);

        _internalBalance[from] -= internalAmt;
        _internalBalance[to] += internalAmt;

        // update scaling/base for both parties
        userBaseBalance[from] = _internalBalance[from];
        userLastScaling[from] = scalingFactor;

        userBaseBalance[to] = _internalBalance[to];
        userLastScaling[to] = scalingFactor;

        emit Transfer(from, to, amount);
        return true;
    }
}
