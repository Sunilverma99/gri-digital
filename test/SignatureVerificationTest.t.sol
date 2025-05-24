// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "contracts/libs/SignatureVerifier.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/* ───────────────────────────────────────────────────────────── */
/*  External wrapper — gives us an extra call-depth              */
/* ───────────────────────────────────────────────────────────── */
contract SigVerifierHarness {
    function recover(bytes32 digest, bytes calldata sig)
        external
        pure
        returns (address)
    {
        return SignatureVerifier.recoverSigner(digest, sig);
    }
}

/* ───────────────────────────────────────────────────────────── */
/*  Tests                                                       */
/* ───────────────────────────────────────────────────────────── */
contract SignatureVerificationTest is Test {
    uint256 private constant SIGNER_PK = 0xBEEF;
    address private           signer;
    SigVerifierHarness        harness;

    function setUp() public {
        signer   = vm.addr(SIGNER_PK);
        harness  = new SigVerifierHarness();
    }

    /* ------------------------- happy-path ------------------------- */
    function testRecoverValidSignature() public view {
        bytes32 digest  = keccak256("unit-test-payload");
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(digest);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PK, ethHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        address recovered = harness.recover(digest, sig);
        assertEq(recovered, signer);
    }

    /* ------------------------- negative-path ---------------------- */
    function testRevertOnBadSignatureLength() public {
        bytes32 digest   = keccak256("bad-sig-case");
        bytes memory bad = hex"DEADBEEF";               // 4-byte garbage sig

        // Expect OZ custom-error: ECDSAInvalidSignatureLength(bad.length)
        vm.expectRevert(
            abi.encodeWithSelector(
                ECDSA.ECDSAInvalidSignatureLength.selector,
                uint256(bad.length)
            )
        );

        harness.recover(digest, bad);                   // external call → revert
    }
}
