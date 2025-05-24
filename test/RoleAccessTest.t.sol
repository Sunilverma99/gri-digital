// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "contracts/managers/RoleManager.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

contract RoleManagerTest is Test {
    RoleManager manager;

    address internal constant ADMIN      = address(0xA11CE);
    address internal constant WRITER     = address(0x1234);
    address internal constant REVIEWER   = address(0xABCD);
    address internal constant NON_ADMIN  = address(0x789);

    /*─────────────────────────── Setup ────────────────────────────*/
    function setUp() public {
        vm.prank(ADMIN);                // deploy from ADMIN
        manager = new RoleManager(ADMIN);
    }

    /*──────────────────── Writer role happy-path ──────────────────*/
    function testGrantAndRevokeWriterRole() public {
        vm.prank(ADMIN);
        manager.grantWriter(WRITER);
        assertTrue(manager.hasWriterRole(WRITER));

        vm.prank(ADMIN);
        manager.revokeWriter(WRITER);
        assertFalse(manager.hasWriterRole(WRITER));
    }

    /*────────────────── Reviewer role happy-path ──────────────────*/
    function testGrantAndRevokeReviewerRole() public {
        vm.prank(ADMIN);
        manager.grantReviewer(REVIEWER);
        assertTrue(manager.hasReviewerRole(REVIEWER));

        vm.prank(ADMIN);
        manager.revokeReviewer(REVIEWER);
        assertFalse(manager.hasReviewerRole(REVIEWER));
    }

    /*────────────── Non-admin attempt must revert ─────────────────*/
    function testOnlyAdminCanGrantRoles() public {
        vm.prank(NON_ADMIN);

        // Expect the exact AccessControl custom-error
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                NON_ADMIN,
                bytes32(0)      // DEFAULT_ADMIN_ROLE
            )
        );

        manager.grantWriter(WRITER);    // should revert
    }
}
