// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {UnstakeRequestsManager} from "@/contracts/L1/core/UnstakeRequestsManager.sol";
import "../src/contracts/access/proxy/Proxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import  {ITransparentUpgradeableProxy}  from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/Script.sol";


// forge script ./script/L1UnStakeRequestsManagerUpgrade.s.sol:L1UnStakeRequestsManagerUpgrade --private-key xxx  --rpc-url https://rpc.holesky.ethpandaops.io  --broadcast -vvvv --legacy --gas-price 1000000000 
contract L1UnStakeRequestsManagerUpgrade is Script {
    UnstakeRequestsManager      public unStakeRequestsManager;
    function run() external {
        vm.startBroadcast();
        address oldContract = 0x435D5C096C423045Fcef329dE32B8CeBc2619205;
        address admin = 0x58B473DAe6202060a2C33395F321d5025799A39D;
        unStakeRequestsManager = new UnstakeRequestsManager();
        ProxyAdmin(admin).upgradeAndCall(ITransparentUpgradeableProxy(oldContract),address(unStakeRequestsManager),bytes(""));

        
        vm.stopBroadcast();
    }

}
