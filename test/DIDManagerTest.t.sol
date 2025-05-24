// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/managers/DIDManager.sol";

contract DIDManagerTest is Test {
    DIDManager public manager;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this); // the test contract acts as the owner
        user1 = address(0x123);
        user2 = address(0x456);

        manager = new DIDManager(owner);
    }

    function test_RegisterDID() public {
        string memory did = "did:web:user1.example";

        manager.registerDID(user1, did);

        assertEq(manager.getDID(user1), did);
        assertEq(manager.resolveAccount(did), user1);
        assertTrue(manager.hasDID(user1));
    }

    function test_RevertWhen_RegisteringDuplicateDID() public {
        manager.registerDID(user1, "did:web:example");

        vm.expectRevert("DIDManager: DID taken");
        manager.registerDID(user2, "did:web:example");
    }

    function test_RevertWhen_RegisteringTwiceForSameAccount() public {
        manager.registerDID(user1, "did:web:a");

        vm.expectRevert("DIDManager: account already has DID");
        manager.registerDID(user1, "did:web:b");
    }

    function test_UpdateDID() public {
        manager.registerDID(user1, "did:web:old");

        manager.updateDID(user1, "did:web:new");

        assertEq(manager.getDID(user1), "did:web:new");
        assertEq(manager.resolveAccount("did:web:new"), user1);
    }

    function test_RevertWhen_UpdatingMissingDID() public {
        vm.expectRevert("DIDManager: missing");
        manager.updateDID(user1, "did:web:new");
    }

    function test_DeleteDID() public {
        string memory did = "did:web:to-delete";
        manager.registerDID(user1, did);

        manager.deleteDID(user1);

        assertEq(manager.getDID(user1), "");
        assertEq(manager.resolveAccount(did), address(0));
        assertFalse(manager.hasDID(user1));
    }

    function test_RevertWhen_DeletingMissingDID() public {
        vm.expectRevert("DIDManager: missing");
        manager.deleteDID(user1);
    }
}
