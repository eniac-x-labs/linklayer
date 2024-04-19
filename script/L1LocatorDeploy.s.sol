// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "@/contracts/L1/core/DETH.sol";
import "@/contracts/L1/core/StakingManager.sol";
import "@/contracts/L1/core/L1Locator.sol";
import "../src/contracts/access/proxy/Proxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import  {ITransparentUpgradeableProxy}  from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/Script.sol";

// forge script ./script/L1LocatorDeploy.s.sol:L1LocatorDeploy --private-key xxxx  --rpc-url https://rpc.holesky.ethpandaops.io  --broadcast -vvvv --legacy --gas-price 1000000000 
contract L1LocatorDeploy is Script {
    L1Locator      public locator;
    DETH                   public dETH;
    function run() external {
        vm.startBroadcast();
        address oldContract = 0xA7d7f12F6F4037a6a80A3261806470bE2C4e08Fc;

        L1Locator.Config memory _config = L1Locator.Config({
            consensusLayerReceiver: 0x217E52f077353A26565035473DB721506E56fF65,
            pauser: 0x790Ff446d2d436326d8e64e7057Cd4f8c0e09c7D,
            dETH: 0x53dEcc85a54b4ea3cD2A6bc610C47797dfB74A75,
            executionLayerReceiver: 0xd3547E7b3FD410BcF793Fc9b73AE6d543d08db38,
            oracleManager: 0xB6BEB33B42A42F1783CC1C8EbfdB7FA6B1746ae5,
            oracleQuorumManager: 0xBCB6Bcd7eF7F68c8a29F9e6F21F405486a7B4933,
            returnsAggregator: 0xacabb3392E265a2B8b7B3FB5Ac5627340462282d,
            stakingManager: 0xB5e392eaB0971D4C98a4a8038f42314f5b6a4c29,
            unStakingRequestsManager: 0x435D5C096C423045Fcef329dE32B8CeBc2619205,
            dapplinkBridge: 0x78de729757Ef7C48c76C9EEe35B38Cc7108d59ca,
            depositContract: 0x4242424242424242424242424242424242424242,
            relayerAddress: 0x2822E13eF080475e8CaBe39b3dc65c6dbe9b083a
        });
        locator = new L1Locator(_config);
        
        vm.writeFile("data/L1/locator.addr", vm.toString(address(locator)));

        vm.stopBroadcast();
    }

}
