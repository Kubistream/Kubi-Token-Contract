// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

/// @notice Shared helper for scripts that need to work with multiple token profiles.
abstract contract TokenProfileScript is Script {
    // Default profile is MUSDC to match the sample env files
    string internal constant DEFAULT_PROFILE = "MUSDC";

    function _activeProfile() internal view returns (string memory) {
        return vm.envOr("TOKEN_PROFILE", DEFAULT_PROFILE);
    }

    function _profileKey(string memory profile, string memory suffix) internal pure returns (string memory) {
        return string.concat("TOKEN_", profile, "_", suffix);
    }

    function _profileString(
        string memory profile,
        string memory suffix,
        string memory globalKey,
        string memory defaultValue
    ) internal view returns (string memory) {
        string memory globalValue = vm.envOr(globalKey, defaultValue);
        return vm.envOr(_profileKey(profile, suffix), globalValue);
    }

    function _profileUint(string memory profile, string memory suffix, string memory globalKey, uint256 defaultValue)
        internal
        view
        returns (uint256)
    {
        uint256 globalValue = vm.envOr(globalKey, defaultValue);
        return vm.envOr(_profileKey(profile, suffix), globalValue);
    }

    function _profileAddress(string memory profile, string memory suffix, string memory globalKey, address defaultValue)
        internal
        view
        returns (address)
    {
        address globalValue = vm.envOr(globalKey, defaultValue);
        return vm.envOr(_profileKey(profile, suffix), globalValue);
    }

    function _profileAddressOrZero(string memory profile, string memory suffix) internal view returns (address) {
        string memory key = _profileKey(profile, suffix);
        return vm.envOr(key, address(0));
    }

    function _tokenAddressForChain(string memory profile, uint256 chainId) internal view returns (address) {
        // Address is shared across chains; first try profile-specific, then global fallback.
        string memory generalProfileKey = string.concat("TOKEN_ADDRESS_", profile);
        address profileGeneral = vm.envOr(generalProfileKey, address(0));
        if (profileGeneral != address(0)) {
            return profileGeneral;
        }
        address globalAddress = vm.envOr("TOKEN_ADDRESS", address(0));
        require(globalAddress != address(0), "TOKEN_ADDRESS missing");
        return globalAddress;
    }
}
