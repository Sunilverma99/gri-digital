// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RoleManager
 * @notice Grants and revokes GRI-specific roles.
 *         Must be deployed and owned by an admin account.
 */
contract RoleManager is AccessControl {
    bytes32 public constant ROLE_WRITER   = keccak256("ROLE_WRITER");
    bytes32 public constant ROLE_REVIEWER = keccak256("ROLE_REVIEWER");

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /*────────────────────────── Writer Role ──────────────────────────*/
    function grantWriter(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ROLE_WRITER, account);
    }

    function revokeWriter(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ROLE_WRITER, account);
    }

    /*────────────────────────── Reviewer Role ───────────────────────*/
    function grantReviewer(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ROLE_REVIEWER, account);
    }

    function revokeReviewer(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ROLE_REVIEWER, account);
    }

    /*────────────────────────── View Helpers ────────────────────────*/
    function hasWriterRole(address account) external view returns (bool) {
        return hasRole(ROLE_WRITER, account);
    }

    function hasReviewerRole(address account) external view returns (bool) {
        return hasRole(ROLE_REVIEWER, account);
    }
}
