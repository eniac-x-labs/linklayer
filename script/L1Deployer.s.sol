// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import "../src/contracts/access/proxy/Proxy.sol";

import "forge-std/Script.sol";


contract L1Deployer is Script {
    ProxyAdmin public proxyAdmin;
    address admin;
    address _depositContract;
    address bridgel1;
    bytes32 _withdrawalCredentials;
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    function setUp() public {
        admin = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        _depositContract = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
        bridgel1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        _withdrawalCredentials = 0x01000000000000000000000089a65b936290915158ac4a2d66f77c961dfac685;
    }
    function run() external {
         vm.startBroadcast();



         vm.stopBroadcast();
    }
}