// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../core/GRIPassportCore.sol";

/**
 * @title GRIPassportQuery
 * @notice Read-only utility contract for paginated / filtered access to disclosures.
 */
contract GRIPassportQuery {
    GRIPassportCore public immutable core;

    constructor(address core_) {
        core = GRIPassportCore(core_);
    }

    /**
     * @dev Paginate disclosures for UI – returns slice [start, start+pageSize).
     */
    function getDisclosuresPaged(
        bytes32 passportId,
        uint256 start,
        uint256 pageSize
    ) external view returns (GRIPassportCore.Disclosure[] memory slice) {
        GRIPassportCore.Disclosure[] memory all = core.getDisclosures(passportId);
        if (start >= all.length) return slice;
        uint256 end = start + pageSize;
        if (end > all.length) end = all.length;
        uint256 len = end - start;
        slice = new GRIPassportCore.Disclosure[](len);
        for (uint256 i; i < len; ++i) {
            slice[i] = all[start + i];
        }
    }

    /** Returns the newest disclosure for a given passport. */
    function latest(bytes32 passportId) external view returns (GRIPassportCore.Disclosure memory) {
        GRIPassportCore.Disclosure[] memory arr = core.getDisclosures(passportId);
        require(arr.length > 0, "none");
        return arr[arr.length - 1];
    }
}
