// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "@/contracts/L1/core/StakingManager.sol";
import "../src/contracts/access/proxy/Proxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import  {ITransparentUpgradeableProxy}  from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/Script.sol";


// forge script ./script/L1StakingManagerUpgrade.s.sol:L1StakingManagerUpgrade --rpc-url https://rpc.holesky.ethpandaops.io 
contract L1StakingManagerUpgrade is Script {
    StakingManager      public stakerManager;
    function run() external {
        vm.startBroadcast();
        address oldContract = 0xf72ef31B541154b07541fDFFc1DAb054852ab770;
        address admin = 0xF07949210f6120cd1A5F5a7897Ed212d6Ebe8F26;
        stakerManager = new StakingManager();
        ProxyAdmin(admin).upgradeAndCall(ITransparentUpgradeableProxy(oldContract),address(stakerManager),bytes(""));

        // Proxy(payable(oldContract)).withdraw();
        
        vm.stopBroadcast();
    }

}
