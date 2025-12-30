// SPDX-License-Identifier: MIT
// Enhanced version with workflow support
pragma solidity ^0.8.20;

import {HypERC20} from "@hyperlane-xyz/core/token/HypERC20.sol";
import {Message} from "@hyperlane-xyz/core/token/libs/Message.sol";
import {TypeCasts} from "@hyperlane-xyz/core/libs/TypeCasts.sol";

/// @title TokenHypERC20
/// @notice Hyperlane ERC20 with optional IGP support and owner-gated mint/burn
/// @dev Uses standard `transferRemote`; payload/workflow hooks removed for simplicity.
contract TokenHypERC20 is HypERC20 {
    using TypeCasts for address;

    constructor(
        address mailbox,
        uint8 decimals_,
        string memory name_,
        string memory symbol_,
        address interchainGasPaymaster_,
        address interchainSecurityModule_,
        address owner_,
        uint256 initialSupply_
    ) HypERC20(decimals_) {
        _demoInit(mailbox, interchainGasPaymaster_, interchainSecurityModule_, owner_, name_, symbol_, initialSupply_);
    }

    function _demoInit(
        address mailbox_,
        address interchainGasPaymaster_,
        address interchainSecurityModule_,
        address owner_,
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_
    ) internal initializer {
        if (interchainGasPaymaster_ == address(0)) {
            __HyperlaneConnectionClient_initialize(mailbox_);
            if (interchainSecurityModule_ != address(0)) {
                _setInterchainSecurityModule(interchainSecurityModule_);
            }
            _transferOwnership(owner_);
        } else {
            __HyperlaneConnectionClient_initialize(mailbox_, interchainGasPaymaster_, interchainSecurityModule_, owner_);
        }
        __ERC20_init(name_, symbol_);
        _mint(owner_, initialSupply_);
    }

    function transferRemote(
        uint32 _destination,
        bytes32 _recipient,
        uint256 _amount
    ) public payable override returns (bytes32 messageId) {
        (bytes memory metadata, uint256 gasPayment) = _pullFundsAndGas(_amount, msg.value);
        bytes memory outboundMessage = Message.format(_recipient, _amount, metadata);
        messageId = _dispatchStandard(_destination, _recipient, _amount, gasPayment, outboundMessage);
    }

    function _pullFundsAndGas(uint256 _amount, uint256 nativeValue)
        internal
        returns (bytes memory metadata, uint256 gasPayment)
    {
        metadata = _transferFromSender(_amount);
        gasPayment = nativeValue;
    }

    function _dispatchStandard(
        uint32 _destination,
        bytes32 _recipient,
        uint256 _amount,
        uint256 gasPayment,
        bytes memory outboundMessage
    ) internal returns (bytes32) {
        if (address(interchainGasPaymaster) == address(0)) {
            require(gasPayment == 0, "IGP not configured");
            bytes32 messageId = _dispatch(_destination, outboundMessage);
            emit SentTransferRemote(_destination, _recipient, _amount);
            return messageId;
        }

        bytes32 messageId = _dispatchWithGas(_destination, outboundMessage, gasPayment, msg.sender);
        emit SentTransferRemote(_destination, _recipient, _amount);
        return messageId;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
