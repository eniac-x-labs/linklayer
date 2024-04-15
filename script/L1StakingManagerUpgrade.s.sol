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
        address oldContract = 0xA127E9fd9Af136C8dC03A78e343fBF41164A8e73;
        address admin = 0xA127E9fd9Af136C8dC03A78e343fBF41164A8e73;
        stakerManager = new StakingManager();
        ProxyAdmin(admin).upgradeAndCall(ITransparentUpgradeableProxy(oldContract),address(stakerManager),bytes(""));

        // Proxy(payable(oldContract)).withdraw();
        
        vm.stopBroadcast();
    }

}
