// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "contracts/core/GRIPassportCore.sol";
import "contracts/queries/GRIPassportQuery.sol";
import "contracts/managers/DIDManager.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract QueryTest is Test {
    DIDManager       did;
    GRIPassportCore  core;
    GRIPassportQuery query;

    uint256 private writerPk = 0xBEEF;
    address private writer = vm.addr(writerPk);

    string  private constant DID_STR = "WasteDept";
    bytes32 private constant passportId = keccak256(abi.encodePacked(DID_STR));
    bytes32 private periodHash = keccak256(abi.encodePacked("FY2024-Q1"));
    bytes32 private zkProof    = bytes32(0);

    function _sig(bytes32 digest, uint256 pk) internal pure returns (bytes memory) {
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(digest);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, ethHash);
        return abi.encodePacked(r, s, v);
    }

    function setUp() public {
        did = new DIDManager(address(this));
        did.registerDID(writer, DID_STR);

        core = new GRIPassportCore();                        // step 1: deploy
        core.initialize(address(this), address(did)); 
        query = new GRIPassportQuery(address(core));

        core.grantRole(core.ROLE_WRITER(), writer);
    }

    function testPagination() public {
        for (uint256 i = 0; i < 12; ++i) {
            string memory dynamicCode = string(abi.encodePacked("GRI-306-", vm.toString(i)));
            bytes32 dataHash = keccak256(abi.encodePacked(i));
            bytes32 digest = keccak256(abi.encodePacked(dataHash, i, block.chainid));
            bytes memory sig = _sig(digest, writerPk);

            vm.prank(writer);
            core.submitDisclosure(
                passportId,
                dynamicCode,
                periodHash,
                dataHash,
                zkProof,
                sig,
                digest,
                i
            );
        }

        GRIPassportCore.Disclosure[] memory page = query.getDisclosuresPaged(passportId, 0, 10);
        assertEq(page.length, 10);
    }

    function testLatestDisclosure() public {
        for (uint256 i = 0; i < 3; ++i) {
            string memory dynamicCode = string(abi.encodePacked("GRI-306-", vm.toString(i)));
            bytes32 dataHash = keccak256(abi.encodePacked(i));
            bytes32 digest = keccak256(abi.encodePacked(dataHash, i, block.chainid));
            bytes memory sig = _sig(digest, writerPk);

            vm.prank(writer);
            core.submitDisclosure(
                passportId,
                dynamicCode,
                periodHash,
                dataHash,
                zkProof,
                sig,
                digest,
                i
            );
        }

        GRIPassportCore.Disclosure memory latest = query.latest(passportId);
        assertEq(latest.dataHash, keccak256(abi.encodePacked(uint256(2))));
    }
}
