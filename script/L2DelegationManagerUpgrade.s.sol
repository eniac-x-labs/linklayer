// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "@/contracts/L2/core/DelegationManager.sol";
// import "@/contracts/L2/core/DelegationManagerUpgrade.sol";
import "../src/contracts/access/proxy/Proxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import  {ITransparentUpgradeableProxy}  from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/Script.sol";

contract L2DelegationManagerUpgrade is Script {
    DelegationManager      public delegationManager;
    function run() external {
        vm.startBroadcast();
        address oldContract = 0x646C2d0a511E93de847b443734796A5A4c798933;
        address admin = 0x9495DB09172189895d89DBa6Ccd002fA1093f9ba;
        delegationManager = new DelegationManager();
        ProxyAdmin(admin).upgradeAndCall(ITransparentUpgradeableProxy(oldContract),address(delegationManager),bytes(""));

        
        vm.stopBroadcast();
    }

}
