// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "@/contracts/L2/strategies/StrategyBase.sol";
import "@/contracts/L2/strategies/StrategyBaseUpgrade.sol";
import "../src/contracts/access/proxy/Proxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import  {ITransparentUpgradeableProxy}  from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/Script.sol";

contract L2StrategyUpgrade is Script {
    StrategyBaseUpgrade      public strategyBase;
    function run() external {
        vm.startBroadcast();
        address oldContract = 0x927dc651EE7b9D8FF3D59E4375fd8E915b6Be920;
        address admin = 0x085558502A1FaE8C9218c5dfF6720ccE6b8e47cf;
        strategyBase = new StrategyBaseUpgrade();
        ProxyAdmin(admin).upgradeAndCall(ITransparentUpgradeableProxy(oldContract),address(strategyBase),bytes(""));

        // Proxy(payable(oldContract)).withdraw();
        
        vm.stopBroadcast();
    }

}
