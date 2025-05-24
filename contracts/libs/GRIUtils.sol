// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;


/// @title GRIUtils
/// @notice Utility library for GRI passport operations
library GRIUtils {
    /// @notice Encode disclosureCode and period into a unique key
    function disclosureKey(string memory code, bytes32 period) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(code, period));
    }

    /// @notice Encode a DID string into a passportId
    function toPassportId(string memory did) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(did));
    }

    /// @notice Hash of a disclosure submission payload (off-chain)
    function hashDisclosurePayload(
        bytes32 dataHash,
        uint256 nonce,
        uint256 chainId
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(dataHash, nonce, chainId));
    }
}
