// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/core/GRIPassportCore.sol";
import "../contracts/managers/DIDManager.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "forge-std/console.sol";  // Logging for Forge

contract RealGRIScenarioTest is Test {
    DIDManager did;
    GRIPassportCore core;

    address[] writers;
    string[] dids;
    string[] gricodes;

    uint256 private adminPk = 0xA11C3D;
    address private admin = vm.addr(adminPk);

    uint256 private reviewerPk = 0xBEEF;
    address private reviewer = vm.addr(reviewerPk);

    bytes32 private period = keccak256(abi.encodePacked("FY2024-Q1"));
    bytes32 private zkProof = bytes32(0);

    function _sig(bytes32 digest, uint256 pk) internal pure returns (bytes memory) {
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(digest);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, ethHash);
        return abi.encodePacked(r, s, v);
    }

    function setUp() public {
    did = new DIDManager(admin);

    vm.startPrank(admin);
    core = new GRIPassportCore();
    core.initialize(admin, address(did));

    core.grantRole(core.ROLE_REVIEWER(), reviewer);

    // W3C-compliant DIDs
    dids = [
        "did:web:marklytics.com:finance",
        "did:web:marklytics.com:energy",
        "did:web:marklytics.com:waste",
        "did:web:marklytics.com:water",
        "did:web:marklytics.com:hr",
        "did:web:marklytics.com:legal",
        "did:web:marklytics.com:it",
        "did:web:marklytics.com:procurement",
        "did:web:marklytics.com:transport",
        "did:web:marklytics.com:compliance"
    ];

    gricodes = [
        "GRI-300-0", "GRI-301-0", "GRI-302-0", "GRI-303-0", "GRI-304-0",
        "GRI-305-0", "GRI-306-0", "GRI-307-0", "GRI-308-0", "GRI-309-0"
    ];

    for (uint256 i = 0; i < dids.length; i++) {
        uint256 pk = uint256(keccak256(abi.encodePacked(dids[i])));
        address addr = vm.addr(pk);
        writers.push(addr);

        did.registerDID(addr, dids[i]);             // ← Now called as admin
        core.grantRole(core.ROLE_WRITER(), addr);   // ← Still admin
    }

    vm.stopPrank();
}



    function test_RealisticGRIWorkflows() public {
        for (uint256 i = 0; i < writers.length; i++) {
            address writer = writers[i];
            string memory didStr = dids[i];
            string memory code = gricodes[i];
            bytes32 passport = keccak256(abi.encodePacked(didStr));
            bytes32 dataHash = keccak256(abi.encodePacked(didStr, code));
            bytes32 digest = keccak256(abi.encodePacked(dataHash, uint256(0), block.chainid));
            uint256 pk = uint256(keccak256(abi.encodePacked(didStr)));

            bytes memory sig = _sig(digest, pk);

            vm.startPrank(writer);
            core.submitDisclosure(passport, code, period, dataHash, zkProof, sig, digest, 0);
            vm.stopPrank();

            GRIPassportCore.Disclosure[] memory list = core.getDisclosures(passport);
            assertEq(list.length, 1);

            console.log("Department DID  : %s", didStr);
            console.log("   Writer        : %s", writer);
            console.log("   GRI Code      : %s", code);
            console.log("   Data Hash     :");
            console.logBytes32(dataHash);
            console.log("   Status        : %d", list[0].status);
            console.log("   Submitted By  : %s", list[0].submittedBy);
            console.log("   Timestamp     : %d", list[0].timestamp);
            console.log("-----------------------------");
        }
    }
}
