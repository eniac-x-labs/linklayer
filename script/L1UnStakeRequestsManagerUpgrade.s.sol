// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {UnstakeRequestsManager} from "@/contracts/L1/core/UnstakeRequestsManager.sol";
import "../src/contracts/access/proxy/Proxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import  {ITransparentUpgradeableProxy}  from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/Script.sol";


// forge script ./script/L1UnStakeRequestsManagerUpgrade.s.sol:L1UnStakeRequestsManagerUpgrade --rpc-url https://rpc.holesky.ethpandaops.io 
contract L1UnStakeRequestsManagerUpgrade is Script {
    UnstakeRequestsManager      public unStakeRequestsManager;
    function run() external {
        vm.startBroadcast();
        address oldContract = 0x9D8cdcBEB831caf1479EBAEdbe0B38350e037af4;
        address admin = 0x391D07433222b64F0e39FDB279e695Da7c91E79A;
        unStakeRequestsManager = new UnstakeRequestsManager();
        ProxyAdmin(admin).upgradeAndCall(ITransparentUpgradeableProxy(oldContract),address(unStakeRequestsManager),bytes(""));

        
        vm.stopBroadcast();
    }

}
