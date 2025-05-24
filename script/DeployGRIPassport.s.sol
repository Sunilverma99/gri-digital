// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/core/GRIPassportCore.sol";
import "../contracts/managers/DIDManager.sol";    

contract DeployGRIPassport is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy DIDManager with deployer as admin
        DIDManager didManager = new DIDManager(deployer);
        console.log("DIDManager deployed at:", address(didManager));

        // Deploy GRIPassportCore with deployer as admin
        // Deploy GRIPassportCore (UUPS pattern)
        GRIPassportCore griPassport = new GRIPassportCore();
        griPassport.initialize(deployer, address(didManager));
        console.log("GRIPassportCore deployed at:", address(griPassport));

        vm.stopBroadcast();
    }
}
