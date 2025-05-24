// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IGRIPassportCore {
    /*─────────────────────────────── Structs ───────────────────────────────*/
    struct Disclosure {
        string  disclosureCode;
        bytes32 period;
        bytes32 dataHash;
        bytes32 zkProofHash;
        address submittedBy;
        uint64  timestamp;
        uint8   status;
    }

    /*─────────────────────────────── Events ───────────────────────────────*/
    event DisclosureSubmitted(
        bytes32 indexed passportId,
        string  indexed disclosureCode,
        bytes32 indexed period,
        address submittedBy,
        bytes32 dataHash,
        bytes32 zkProofHash,
        uint256 nonce,
        uint64  timestamp
    );

    event DisclosureReviewed(
        bytes32 indexed passportId,
        string  indexed disclosureCode,
        bytes32 indexed period,
        bool    approved,
        address reviewer,
        uint64  timestamp
    );

    event PeriodFrozen(
        bytes32 indexed passportId,
        bytes32 indexed period,
        address frozenBy,
        uint64  timestamp
    );

    /*─────────────────────────────── Errors ───────────────────────────────*/
    error ErrPeriodFrozen();
    error DuplicateDisclosure();
    error InvalidSignature();
    error EmptyHash();
    error InvalidGRICode();
    error NonceMismatch();
    error UnregisteredDID();
    error PassportIdMismatch();

    /*────────────────────────────── Functions ──────────────────────────────*/
    function submitDisclosure(
        bytes32 passportId,
        string calldata disclosureCode,
        bytes32 period,
        bytes32 dataHash,
        bytes32 zkProofHash,
        bytes calldata sig,
        bytes32 digest,
        uint256 nonce
    ) external;

    function reviewDisclosure(
        bytes32 passportId,
        uint256 index,
        bool approve
    ) external;

    function freezePeriod(
        bytes32 passportId,
        bytes32 period
    ) external;

    function getDisclosures(
        bytes32 passportId
    ) external view returns (Disclosure[] memory);

    function isPeriodFrozen(
        bytes32 passportId,
        bytes32 period
    ) external view returns (bool);

    function getPassportOwner(
        bytes32 passportId
    ) external view returns (address);

    function getPassportId(
        address owner
    ) external view returns (bytes32);

    function pause() external;

    function unpause() external;
}
