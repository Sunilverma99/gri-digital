// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/managers/DIDManager.sol";
import "../contracts/core/GRIPassportCore.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract GRIPassportCoreTest is Test {
    DIDManager      did;
    GRIPassportCore core;

    /*────────────────────────── Test actors ──────────────────────────*/
    uint256 private writerPk   = 0xA11CE;
    address private writer     = vm.addr(writerPk);

    uint256 private reviewerPk = 0xB0B;
    address private reviewer   = vm.addr(reviewerPk);

    /*────────────────────────── Constants ────────────────────────────*/
    // DID string & its keccak256 hash used by the contract
    string  private constant DID_STR   = "FinanceDept";
    bytes32 private constant PASSPORT  = keccak256(abi.encodePacked(DID_STR));

    bytes32 private periodHash = keccak256(abi.encodePacked("FY2024-Q1"));
    string  private code       = "GRI-201-1";
    bytes32 private dataHash   = keccak256(abi.encodePacked("dummy"));
    bytes32 private zkProof    = bytes32(0);

    /*────────────────────────── Helpers ──────────────────────────────*/
    function _sig(bytes32 digest, uint256 pk) internal pure returns (bytes memory) {
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(digest);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, ethHash);
        return abi.encodePacked(r, s, v);
    }

    /*────────────────────────── setUp() ──────────────────────────────*/
    function setUp() public {
        /* 1. Deploy & seed DID registry */
        did = new DIDManager(address(this));
        did.registerDID(writer, DID_STR);

        /* 2. Deploy core + role setup */
        core = new GRIPassportCore();                        // step 1: deploy
        core.initialize(address(this), address(did));        // step 2: initialize
        core.grantRole(core.ROLE_WRITER(),   writer);
        core.grantRole(core.ROLE_REVIEWER(), reviewer);
    }

    /*──────────────── Positive path: submit ────────────────*/
    function testSubmitDisclosure() public {
        bytes32 digest = keccak256(abi.encodePacked(dataHash, uint256(0), block.chainid));

        vm.prank(writer);
        core.submitDisclosure(
            PASSPORT, code, periodHash, dataHash, zkProof,
            _sig(digest, writerPk), digest, 0
        );

        assertEq(core.nonces(writer), 1);
        assertEq(core.getDisclosures(PASSPORT).length, 1);
    }

    /*──────────────── Duplicate guard ──────────────────────*/
    function testDuplicateDisclosureReverts() public {
        bytes32 digest0 = keccak256(abi.encodePacked(dataHash, uint256(0), block.chainid));
        vm.prank(writer);
        core.submitDisclosure(PASSPORT, code, periodHash, dataHash, zkProof, _sig(digest0, writerPk), digest0, 0);

        bytes32 digest1 = keccak256(abi.encodePacked(dataHash, uint256(1), block.chainid));
        vm.prank(writer);
        vm.expectRevert(GRIPassportCore.DuplicateDisclosure.selector);
        core.submitDisclosure(PASSPORT, code, periodHash, dataHash, zkProof, _sig(digest1, writerPk), digest1, 1);
    }

    /*──────────────── Nonce mismatch ───────────────────────*/
    function testWrongNonceReverts() public {
        bytes32 digest = keccak256(abi.encodePacked(dataHash, uint256(5), block.chainid));
        vm.prank(writer);
        vm.expectRevert(GRIPassportCore.NonceMismatch.selector);
        core.submitDisclosure(PASSPORT, code, periodHash, dataHash, zkProof, _sig(digest, writerPk), digest, 5);
    }

    /*──────────────── Bad signature ────────────────────────*/
    function testInvalidSignatureReverts() public {
        bytes32 digest = keccak256(abi.encodePacked(dataHash, uint256(0), block.chainid));
        bytes memory badSig = _sig(digest, reviewerPk); // wrong key

        vm.prank(writer);
        vm.expectRevert(GRIPassportCore.InvalidSignature.selector);
        core.submitDisclosure(PASSPORT, code, periodHash, dataHash, zkProof, badSig, digest, 0);
    }

    /*──────────────── Freeze period ────────────────────────*/
    function testFreezePeriodBlocksSubmission() public {
        vm.prank(reviewer);
        core.freezePeriod(PASSPORT, periodHash);

        bytes32 digest = keccak256(abi.encodePacked(dataHash, uint256(0), block.chainid));
        vm.prank(writer);
        vm.expectRevert(GRIPassportCore.ErrPeriodFrozen.selector);
        core.submitDisclosure(PASSPORT, code, periodHash, dataHash, zkProof, _sig(digest, writerPk), digest, 0);
    }

    /*──────────────── Approval workflow ────────────────────*/
    function testReviewerApprovalFlow() public {
        bytes32 digest = keccak256(abi.encodePacked(dataHash, uint256(0), block.chainid));
        vm.prank(writer);
        core.submitDisclosure(PASSPORT, code, periodHash, dataHash, zkProof, _sig(digest, writerPk), digest, 0);

        vm.prank(reviewer);
        core.reviewDisclosure(PASSPORT, 0, true);

        GRIPassportCore.Disclosure[] memory list = core.getDisclosures(PASSPORT);
        assertEq(list[0].status, 1); // approved
    }
}
