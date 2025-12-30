// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

/// @notice Shared helper for scripts that need to work with multiple token profiles.
abstract contract TokenProfileScript is Script {
    // Default profile is MUSDC to match the sample env files
    string internal constant DEFAULT_PROFILE = "MUSDC";

    function _activeProfile() internal view returns (string memory) {
        string memory raw = vm.envOr("TOKEN_PROFILE", DEFAULT_PROFILE);
        return _firstProfile(raw);
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

    function _firstProfile(string memory raw) internal pure returns (string memory) {
        bytes memory data = bytes(raw);
        uint256 len = data.length;
        // Find first comma; if none, return raw
        bytes1 comma = bytes1(",");
        for (uint256 i = 0; i < len; i++) {
            if (data[i] == comma) {
                // slice bytes [0, i)
                bytes memory out = new bytes(i);
                for (uint256 j = 0; j < i; j++) {
                    out[j] = data[j];
                }
                if (out.length == 0) {
                    return DEFAULT_PROFILE;
                }
                return string(out);
            }
        }
        return raw;
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
