// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "@/contracts/L1/core/StakingManager.sol";
import "../src/contracts/access/proxy/Proxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import  {ITransparentUpgradeableProxy}  from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/Script.sol";


// forge script ./script/L1StakingManagerUpgrade.s.sol:L1StakingManagerUpgrade --private-key xxxx  --rpc-url https://rpc.holesky.ethpandaops.io  --broadcast -vvvv --legacy --gas-price 1000000000 
contract L1StakingManagerUpgrade is Script {
    StakingManager      public stakerManager;
    function run() external {
        vm.startBroadcast();
        address oldContract = 0xB5e392eaB0971D4C98a4a8038f42314f5b6a4c29;
        address admin = 0x3330aA6443fCf3de3Ed6fCC725243De81c7374ec;
        stakerManager = new StakingManager();
        ProxyAdmin(admin).upgradeAndCall(ITransparentUpgradeableProxy(oldContract),address(stakerManager),bytes(""));
        // console.log("address(stakerManager)-------",address(stakerManager));
        vm.stopBroadcast();
    }

}
