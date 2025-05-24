// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


import "../managers/DIDManager.sol";
import "../libs/SignatureVerifier.sol";

/**
 * @title GRIPassportCore (Upgradeable)
 * @notice Production-grade ledger for department-level GRI-2021 disclosures.
 */
contract GRIPassportCore is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    /*────────────────────────────  Roles  ────────────────────────────*/
    bytes32 public constant ROLE_WRITER = keccak256("ROLE_WRITER");
    bytes32 public constant ROLE_REVIEWER = keccak256("ROLE_REVIEWER");

    /*──────────────────────────  Custom errors  ─────────────────────*/
    error ErrPeriodFrozen();
    error DuplicateDisclosure();
    error InvalidSignature();
    error EmptyHash();
    error InvalidGRICode();
    error NonceMismatch();
    error UnregisteredDID();
    error PassportIdMismatch();

    /*────────────────────────────  Registry  ────────────────────────*/
    DIDManager public didManager;

    // passportId ⇒ owner
    mapping(bytes32 => address) private _passportOwner;
    // owner ⇒ passportId
    mapping(address => bytes32) private _ownerPassportId;

    /*──────────────────────────  Data model  ────────────────────────*/
    struct Disclosure {
        string disclosureCode;
        bytes32 period;
        bytes32 dataHash;
        bytes32 zkProofHash;
        address submittedBy;
        uint64 timestamp;
        uint8 status; // 0=pending, 1=approved, 2=rejected
    }

    mapping(bytes32 => Disclosure[]) private _passportDisclosures;
    mapping(bytes32 => mapping(bytes32 => bool)) private _periodFrozen;
    mapping(bytes32 => mapping(bytes32 => bool)) private _submitted;
    mapping(address => uint256) public nonces;

    /*────────────────────────────  Events  ──────────────────────────*/
    event DisclosureSubmitted(
        bytes32 indexed passportId,
        address indexed submittedBy,
        bytes32 indexed dataHash,
        string disclosureCode,
        bytes32 period,
        bytes32 zkProofHash,
        uint256 nonce,
        uint64 timestamp
    );

    event DisclosureReviewed(
        bytes32 indexed passportId,
        string indexed disclosureCode,
        bytes32 indexed period,
        bool approved,
        address reviewer,
        uint64 timestamp
    );

    event PeriodFrozen(
        bytes32 indexed passportId,
        bytes32 indexed period,
        address frozenBy,
        uint64 timestamp
    );

    /*──────────────────────────  Initializer  ───────────────────────*/
    function initialize(address admin, address didManagerAddress) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        didManager = DIDManager(didManagerAddress);
    }

    /*──────────────────────────  UUPS Upgrade  ──────────────────────*/
    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /*──────────────────────────  Core submit  ───────────────────────*/
    function submitDisclosure(
        bytes32 passportId,
        string calldata disclosureCode,
        bytes32 period,
        bytes32 dataHash,
        bytes32 zkProofHash,
        bytes calldata sig,
        bytes32 digest,
        uint256 nonce
    ) external whenNotPaused nonReentrant onlyRole(ROLE_WRITER) {
        string memory didStr = didManager.getDID(msg.sender);
        if (bytes(didStr).length == 0) revert UnregisteredDID();

        bytes32 expectedPassportId = keccak256(abi.encodePacked(didStr));
        if (passportId != expectedPassportId) revert PassportIdMismatch();

        if (_periodFrozen[passportId][period]) revert ErrPeriodFrozen();
        if (bytes(disclosureCode).length < 8) revert InvalidGRICode();
        if (dataHash == bytes32(0)) revert EmptyHash();
        if (nonce != nonces[msg.sender]) revert NonceMismatch();

        bytes32 dupKey = keccak256(abi.encodePacked(disclosureCode, period));
        if (_submitted[passportId][dupKey]) revert DuplicateDisclosure();
        if (SignatureVerifier.recoverSigner(digest, sig) != msg.sender) revert InvalidSignature();

        _submitted[passportId][dupKey] = true;
        nonces[msg.sender]++;

        _passportDisclosures[passportId].push(
            Disclosure({
                disclosureCode: disclosureCode,
                period: period,
                dataHash: dataHash,
                zkProofHash: zkProofHash,
                submittedBy: msg.sender,
                timestamp: uint64(block.timestamp),
                status: 0
            })
        );

        if (_passportOwner[passportId] == address(0)) {
            _passportOwner[passportId] = msg.sender;
            _ownerPassportId[msg.sender] = passportId;
        }

        emit DisclosureSubmitted(
            passportId,
            msg.sender,
            dataHash,
            disclosureCode,
            period,
            zkProofHash,
            nonce,
            uint64(block.timestamp)
        );
    }

    /*───────────────────────  Review & Freeze  ─────────────────────*/
    function reviewDisclosure(bytes32 passportId, uint256 index, bool approve)
        external whenNotPaused onlyRole(ROLE_REVIEWER)
    {
        Disclosure storage d = _passportDisclosures[passportId][index];
        require(d.status == 0, "already");
        d.status = approve ? 1 : 2;
        emit DisclosureReviewed(passportId, d.disclosureCode, d.period, approve, msg.sender, uint64(block.timestamp));
    }

    function freezePeriod(bytes32 passportId, bytes32 period)
        external whenNotPaused onlyRole(ROLE_REVIEWER)
    {
        _periodFrozen[passportId][period] = true;
        emit PeriodFrozen(passportId, period, msg.sender, uint64(block.timestamp));
    }

    /*────────────────────────  View helpers  ────────────────────────*/
    function getDisclosures(bytes32 passportId) external view returns (Disclosure[] memory) {
        return _passportDisclosures[passportId];
    }

    function isPeriodFrozen(bytes32 passportId, bytes32 period) external view returns (bool) {
        return _periodFrozen[passportId][period];
    }

    function getPassportOwner(bytes32 passportId) external view returns (address) {
        return _passportOwner[passportId];
    }

    function getPassportId(address owner) external view returns (bytes32) {
        return _ownerPassportId[owner];
    }

    /*────────────────────────  Admin controls  ──────────────────────*/
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
