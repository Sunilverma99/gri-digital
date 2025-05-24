// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @notice Tiny wrapper to recover the signer of an EIP-191 (“personal_sign”) signature.
library SignatureVerifier {
    /**
     * @param digest 32-byte unhashed message (e.g. keccak256 of your VC JSON + nonce).
     * @param sig    65-byte {r}{s}{v} signature produced by `personal_sign`.
     * @return signer EOA that produced the signature.
     */
    function recoverSigner(bytes32 digest, bytes memory sig) internal pure returns (address signer) {
        // 1. Prefix with "\x19Ethereum Signed Message:\n32" per EIP-191
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(digest);

        // 2. Recover signer (reverts if signature length ≠ 65)
        signer = ECDSA.recover(ethHash, sig);
        require(signer != address(0), "SigVerifier: bad signature");
    }
}
