// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

/*══════════════════════════════════════════════════════════════════════╗
║   DIDManager                                                         ║
║   ──────────                                                         ║
║   • 1-to-1 registry between an EOA and a W3C-DID URI                 ║
║   • Only the contract owner (Ops / multisig) can mutate state        ║
║   • Emits granular events for indexers (The Graph, etc.)             ║
╚══════════════════════════════════════════════════════════════════════*/

contract DIDManager is Ownable {
    /* ─────────────────────────── Constructor ───────────────────────── */

    /// @param admin owner address (e.g. Ops multisig) that will control the registry
    constructor(address admin) Ownable(admin) {
    }

    /* ─────────────────────────── Storage ───────────────────────────── */

    mapping(address => string)  private _addrToDid;       // EOA ⇒ DID
    mapping(bytes32 => address) private _didHashToAddr;   // keccak256(DID) ⇒ EOA

    /* ─────────────────────────── Events ────────────────────────────── */

    event DIDRegistered(address indexed account, string indexed did, uint64 timestamp);
    event DIDUpdated   (address indexed account, string indexed oldDid, string indexed newDid, uint64 timestamp);
    event DIDDeleted   (address indexed account, string indexed did, uint64 timestamp);

    /* ─────────────────────────── Modifiers ─────────────────────────── */

    modifier ensureNewDid(string memory did_) {
        require(bytes(did_).length != 0, "DIDManager: empty DID");
        require(_didHashToAddr[_hash(did_)] == address(0), "DIDManager: DID taken");
        _;
    }

    /* ─────────────────────────── Write API ─────────────────────────── */

    function registerDID(address account, string memory did)
        external
        onlyOwner
        ensureNewDid(did)
    {
        require(bytes(_addrToDid[account]).length == 0, "DIDManager: account already has DID");

        _addrToDid[account]            = did;
        _didHashToAddr[_hash(did)]     = account;

        emit DIDRegistered(account, did, uint64(block.timestamp));
    }

    function updateDID(address account, string memory newDid)
        external
        onlyOwner
        ensureNewDid(newDid)
    {
        string memory oldDid = _addrToDid[account];
        require(bytes(oldDid).length != 0, "DIDManager: missing");

        delete _didHashToAddr[_hash(oldDid)];

        _addrToDid[account]           = newDid;
        _didHashToAddr[_hash(newDid)] = account;

        emit DIDUpdated(account, oldDid, newDid, uint64(block.timestamp));
    }

    function deleteDID(address account)
        external
        onlyOwner
    {
        string memory did = _addrToDid[account];
        require(bytes(did).length != 0, "DIDManager: missing");

        delete _didHashToAddr[_hash(did)];
        delete _addrToDid[account];

        emit DIDDeleted(account, did, uint64(block.timestamp));
    }

    /* ─────────────────────────── Read API ──────────────────────────── */

    function getDID(address account) external view returns (string memory) {
        return _addrToDid[account];
    }

    function resolveAccount(string memory did) external view returns (address) {
        return _didHashToAddr[_hash(did)];
    }

    function hasDID(address account) external view returns (bool) {
        return bytes(_addrToDid[account]).length != 0;
    }

    /* ─────────────────────────── Internals ─────────────────────────── */

    function _hash(string memory s) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(s));
    }
}
