// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "@/contracts/L1/core/DETH.sol";
import "../src/contracts/access/proxy/Proxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import  {ITransparentUpgradeableProxy}  from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/Script.sol";

contract L1DETHUpgrade is Script {
    DETH      public deth;
    function run() external {
        vm.startBroadcast();
        address oldContract = 0xA7d7f12F6F4037a6a80A3261806470bE2C4e08Fc;
        address admin = 0xd2dB3d27E471101633DC4534Bd64FF4352D6ccCB;
        deth = new DETH();
        ProxyAdmin(admin).upgradeAndCall(ITransparentUpgradeableProxy(oldContract),address(deth),bytes(""));

        // Proxy(payable(oldContract)).withdraw();
        
        vm.stopBroadcast();
    }

}
