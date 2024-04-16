// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "@/contracts/L1/core/DETH.sol";
import "@/contracts/L1/core/StakingManager.sol";
import "@/contracts/L1/core/L1Locator.sol";
import "../src/contracts/access/proxy/Proxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import  {ITransparentUpgradeableProxy}  from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/Script.sol";

contract L1LocatorDeploy is Script {
    L1Locator      public locator;
    DETH                   public dETH;
    function run() external {
        vm.startBroadcast();
        address oldContract = 0xA7d7f12F6F4037a6a80A3261806470bE2C4e08Fc;

        L1Locator.Config memory _config = L1Locator.Config({
            stakingManager: 0xf72ef31B541154b07541fDFFc1DAb054852ab770,
            unStakingRequestsManager: 0x9D8cdcBEB831caf1479EBAEdbe0B38350e037af4,
            dETH: 0x2b6e88e9e59294E0391952fc11e1A2969165F43b,
            pauser: 0xD6bc9E187AA1fEDAefc57c453C768923DDeE55a0,
            returnsAggregator: 0x4953BD5A8eB4100A6De128c6767ddbbf38f5eE5d,
            oracleManager: 0xeF0f8fffA9e82efE2A2bCa54dBe949a948905d5E,
            oracleQuorumManager: 0x7e80F4A2606C4794699346584F7Ae1A4F413f94A,
            consensusLayerReceiver: 0x7B4e65e18ab936625F24a7B8211205aE599d6EC7,
            executionLayerReceiver: 0xb71EA362B5b036b700a50498722ceFC41cdE3599,
            dapplinkBridge: 0x78de729757Ef7C48c76C9EEe35B38Cc7108d59ca,
            depositContract: 0x4242424242424242424242424242424242424242,
            relayerAddress: 0x8061C28b479B846872132F593bC7cbC6b6C9D628
        });
        locator = new L1Locator(_config);
        
        vm.writeFile("data/L1/locator.addr", vm.toString(address(locator)));

        vm.stopBroadcast();
    }

}
