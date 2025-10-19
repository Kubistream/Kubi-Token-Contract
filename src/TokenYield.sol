// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract TokenYield is ERC20, Ownable, AccessControl {
    // ====== STORAGE ======
    mapping(address => uint256) internal _internalBalance;
    mapping(address => uint256) public userLastScaling;
    mapping(address => uint256) public userBaseBalance;

    IERC20 public underlyingToken; // token asli (misal USDC)
    address public vault;              // alamat vault yang boleh narik underlying
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
    ) {
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
        require(amount > 0, "invalid amount");
        uint256 internalAmt = (amount * 1e18) / scalingFactor;
        _internalBalance[to] += internalAmt;
        userBaseBalance[to] = _internalBalance[to];
        userLastScaling[to] = scalingFactor;
        emit Mint(to, amount);
    }

    function depositYield(address user, uint256 amount) external onlyDepositorContract {
        require(amount > 0, "TokenYield: invalid amount");

        // 1️⃣ Tarik underlying token dari kontrak caller ke vault
        bool success = underlyingToken.safeTransferFrom(msg.sender, vault, amount);
        require(success, "TokenYield: transfer underlying failed");

        // 2️⃣ Hitung jumlah internal balance berdasarkan scaling
        uint256 internalAmt = (amount * 1e18) / scalingFactor;
        _internalBalance[user] += internalAmt;

        // 3️⃣ Simpan scaling user saat ini
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
        require(newScalingFactor > 0, "invalid scaling");
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
        return (scalingFactor * 1e18) / userScale - 1e18;
    }

    function projectedBalance(address user) public view returns (uint256) {
        return (_internalBalance[user] * scalingFactor) / 1e18;
    }

    // ====== MISC ======
    function burn(address from, uint256 amount) external onlyOwner {
        require(amount > 0, "invalid amount");
        uint256 internalAmt = (amount * 1e18) / scalingFactor;
        require(_internalBalance[from] >= internalAmt, "insufficient");
        _internalBalance[from] -= internalAmt;
        emit Burned(from, amount);
    }


    function redeem(uint256 amount) external {
        require(amount > 0, "invalid amount");

        uint256 internalAmt = (amount * 1e18) / scalingFactor;
        require(_internalBalance[msg.sender] >= internalAmt, "insufficient balance");

        // Burn staking token (kurangi internal balance)
        _internalBalance[msg.sender] -= internalAmt;
        emit Burned(msg.sender, amount);

        // Transfer token asli dari vault ke user
        bool success = underlyingToken.transferFrom(vault, msg.sender, amount);
        require(success, "transfer failed");

        emit Redeemed(msg.sender, amount);
    }

        /// @notice Mengganti alamat vault yang digunakan untuk redeem token
    /// @param newVault Alamat vault baru
    function updateVault(address newVault) external onlyOwner {
        require(newVault != address(0), "TokenYield: invalid vault address");
        require(newVault != vault, "TokenYield: same vault address");

        address oldVault = vault;
        vault = newVault;

        emit VaultUpdated(oldVault, newVault);
    }

    /// @notice Mengganti alamat vault yang digunakan untuk redeem token
    /// @param newVault Alamat vault baru
    function updateDepositorContract(address newDepositorContract) external onlyOwner {
        require(newDepositorContract != address(0), "TokenYield: invalid vault address");
        require(newDepositorContract != depositorContract, "TokenYield: same vault address");

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

    function transfer(address to, uint256 amount) public override returns (bool) {
    uint256 internalAmt = (amount * 1e18) / scalingFactor;
    require(_internalBalance[msg.sender] >= internalAmt, "insufficient balance");
    require(underlyingToken.balanceOf(vault) >= amount, "vault insufficient balance");

    _internalBalance[msg.sender] -= internalAmt;
    _internalBalance[to] += internalAmt;

    emit Transfer(msg.sender, to, amount);
    return true;
}

function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
    uint256 internalAmt = (amount * 1e18) / scalingFactor;
    require(_internalBalance[from] >= internalAmt, "insufficient balance");

    _spendAllowance(from, msg.sender, amount);

    _internalBalance[from] -= internalAmt;
    _internalBalance[to] += internalAmt;

    emit Transfer(from, to, amount);
    return true;
}

}
