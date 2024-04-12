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

        dETH = new DETH();

        Proxy proxyDETH = new Proxy(address(dETH), address(msg.sender), "");

        L1Locator.Config memory _config = L1Locator.Config({
            stakingManager: 0x4e1cec2aEA966714d6A8615dCCf7eee6Ed6668b9,
            unStakingRequestsManager: 0x545f8a383f02679eb2e417b75A47A63856131F82,
            dETH: address(proxyDETH),
            pauser: 0x4AfdDFe2935E7A5DE5b7cAcCB964CE5E1C574771,
            returnsAggregator: 0x8e4A86cd76d2Fe88eB9dA94Baf865b52077704d4,
            oracleManager: 0xc63192787D2a34AAC8a2C051667750154a6e1644,
            oracleQuorumManager: 0xDbBEc9c069F629B0894C3F15eeC73D31eD88C925,
            consensusLayerReceiver: 0x936A2edca78D8eb0BB20A3e70C83C8F9F5b16A95,
            executionLayerReceiver: 0xc56A0479352db4b4633533B0A6Cf4f4d9B07b3eF,
            dapplinkBridge: 0x78de729757Ef7C48c76C9EEe35B38Cc7108d59ca,
            depositContract: 0x4242424242424242424242424242424242424242
        });
        locator = new L1Locator(_config);

          DETH.Init memory initDeth = DETH.Init({
            admin: msg.sender,
            l2ShareAddress: msg.sender
        });
        DETH(address(proxyDETH)).initialize(initDeth);
        DETH(address(proxyDETH)).setLocator(address(locator));
        // StakingManager(payable(0x4e1cec2aEA966714d6A8615dCCf7eee6Ed6668b9)).setLocator(address(locator));
        
        vm.writeFile("data/L1/locator.addr", vm.toString(address(locator)));

        vm.stopBroadcast();
    }

}
