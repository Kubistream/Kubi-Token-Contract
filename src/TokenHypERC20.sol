// SPDX-License-Identifier: MIT
// Enhanced version with workflow support
pragma solidity ^0.8.20;

import {HypERC20} from "@hyperlane-xyz/core/token/HypERC20.sol";
import {Message} from "@hyperlane-xyz/core/token/libs/Message.sol";
import {TypeCasts} from "@hyperlane-xyz/core/libs/TypeCasts.sol";

/// @notice Interface for contracts that receive messages via Hyperlane
interface IHyperlaneRecipient {
    function handle(
        uint32 origin,
        bytes32 sender,
        bytes calldata message
    ) external;
}

/// @title TokenHypERC20
/// @notice Hyperlane ERC20 with optional IGP support and owner-gated mint/burn
/// @dev Supports transferRemote with custom metadata for application-level callbacks
contract TokenHypERC20 is HypERC20 {
    using TypeCasts for address;
    using Message for bytes;

    /// @notice Emitted when a recipient contract is called with custom metadata
    event MetadataCallback(
        uint32 indexed origin,
        address indexed recipient,
        bytes32 sender,
        uint256 amount,
        bytes customMetadata,
        bool success
    );

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

    /// @notice Transfer tokens remotely with custom metadata for application callback
    /// @param _destination Destination chain domain ID
    /// @param _recipient Recipient address as bytes32
    /// @param _amount Amount of tokens to transfer
    /// @param _customMetadata Custom metadata that will be passed to recipient's handle() function
    /// @return messageId The ID of the dispatched message
    function transferRemoteWithMetadata(
        uint32 _destination,
        bytes32 _recipient,
        uint256 _amount,
        bytes memory _customMetadata
    ) public payable returns (bytes32 messageId) {
        (bytes memory transferMetadata, uint256 gasPayment) = _pullFundsAndGas(_amount, msg.value);

        // Combine transfer metadata with custom metadata
        bytes memory combinedMetadata = abi.encode(transferMetadata, _customMetadata);
        bytes memory outboundMessage = Message.format(_recipient, _amount, combinedMetadata);

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

        bytes32 id = _dispatchWithGas(_destination, outboundMessage, gasPayment, msg.sender);
        emit SentTransferRemote(_destination, _recipient, _amount);
        return id;
    }

    function _handle(
        uint32 _origin,
        bytes32 _sender, // _sender - unused but required for override
        bytes calldata _message
    ) internal override {
        // Decode message using library functions
        bytes32 recipient = _message.recipient();
        uint256 amount = _message.amount();
        bytes calldata combinedMetadata = _message.metadata();

        // Extract custom metadata for callback (if any)
        bytes memory customMetadata;

        // For transferRemoteWithMetadata, format is: abi.encode(transferMetadata, customMetadata)
        // We can detect this by checking if metadata looks like encoded bytes tuple
        // Standard transferRemote has empty metadata (bytes(""))
        if (combinedMetadata.length > 32) {
            // Likely has custom metadata, decode it
            (bytes memory transferData, bytes memory customData) =
                abi.decode(combinedMetadata, (bytes, bytes));
            customMetadata = customData;
        }

        // Mint tokens to recipient
        address recipientAddress = TypeCasts.bytes32ToAddress(recipient);
        _transferTo(recipientAddress, amount, combinedMetadata[0:0]); // Empty slice of combinedMetadata

        // If recipient is a contract and has custom metadata, attempt callback
        if (customMetadata.length > 0 && _isRecipientContract(recipientAddress)) {
            try
                IHyperlaneRecipient(recipientAddress).handle(_origin, _sender, customMetadata)
            {
                emit MetadataCallback(_origin, recipientAddress, _sender, amount, customMetadata, true);
            } catch {
                emit MetadataCallback(_origin, recipientAddress, _sender, amount, customMetadata, false);
            }
        }

        // Emit event with correct signature
        emit ReceivedTransferRemote(_origin, recipient, amount);
    }

    /// @notice Check if an address is a contract (for callback check)
    function _isRecipientContract(address addr) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
