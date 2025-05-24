// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/core/GRIPassportCore.sol";
import "../contracts/managers/DIDManager.sol";

contract AssignRolesScript is Script {
    address public coreAddress;      // set via CLI or hardcoded
    address public didAddress;       // set via CLI or hardcoded

    address public writer;           // assign ROLE_WRITER
    address public reviewer;         // assign ROLE_REVIEWER

    function setUp() public {
        // Set via environment variables (or hardcode for dev)
        coreAddress = vm.envAddress("CORE_ADDRESS");
        didAddress  = vm.envAddress("DID_ADDRESS");
        writer      = vm.envAddress("WRITER_ADDRESS");
        reviewer    = vm.envAddress("REVIEWER_ADDRESS");
    }

    function run() public {
        vm.startBroadcast();

        GRIPassportCore core = GRIPassportCore(coreAddress);
        DIDManager did = DIDManager(didAddress);

        // Ensure writer DID is registered
        if (!did.hasDID(writer)) {
            did.registerDID(writer, "FinanceDept");
        }

        // Ensure reviewer DID is registered
        if (!did.hasDID(reviewer)) {
            did.registerDID(reviewer, "AuditDept");
        }

        // Assign writer role if not already assigned
        if (!core.hasRole(core.ROLE_WRITER(), writer)) {
            core.grantRole(core.ROLE_WRITER(), writer);
        }

        // Assign reviewer role if not already assigned
        if (!core.hasRole(core.ROLE_REVIEWER(), reviewer)) {
            core.grantRole(core.ROLE_REVIEWER(), reviewer);
        }

        vm.stopBroadcast();
    }
}
