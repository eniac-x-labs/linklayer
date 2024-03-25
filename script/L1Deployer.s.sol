// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "@/contracts/L1/core/DETH.sol";
import "@/contracts/L1/core/OracleManager.sol";
import "@/contracts/L1/core/OracleQuorumManager.sol";
import "@/contracts/L1/core/ReturnsAggregator.sol";
import "@/contracts/L1/core/ReturnsReceiver.sol";
import "@/contracts/L1/core/StakingManager.sol";
import "@/contracts/L1/core/UnstakeRequestsManager.sol";

import "@/contracts/access/L1Pauser.sol";

import "../src/contracts/access/proxy/Proxy.sol";

import "@/contracts/L1/interfaces/IDepositContract.sol";


import "forge-std/Script.sol";


contract L1Deployer is Script {
    ProxyAdmin             public dappLinkProxyAdmin;
    DETH                   public dETH;
    OracleManager          public oracleManager;
    OracleQuorumManager    public oracleQuorumManager;
    ReturnsAggregator      public returnsAggregator;
    ReturnsReceiver        public returnsReceiver;
    StakingManager         public stakingManager;
    UnstakeRequestsManager public unstakeRequestsManager;
    L1Pauser               public dappLinkPauser;

    function run() external {
        vm.startBroadcast();

        address dappLinkMultisig = msg.sender;
        address admin = msg.sender;
        address relayer = msg.sender;

        dappLinkProxyAdmin = new ProxyAdmin(msg.sender);
        dappLinkPauser = new L1Pauser();
        dETH = new DETH();
        oracleManager = new OracleManager();
        oracleQuorumManager = new OracleQuorumManager();
        returnsAggregator = new ReturnsAggregator();
        returnsReceiver = new ReturnsReceiver();
        stakingManager = new StakingManager();
        unstakeRequestsManager = new UnstakeRequestsManager();

        Proxy proxyDappLinkPauser = new Proxy(address(dappLinkPauser), address(admin), "");
        Proxy proxyDETH = new Proxy(address(dETH), address(admin), "");
        Proxy proxyOracleManager = new Proxy(address(oracleManager), address(admin), "");
        Proxy proxyOracleQuorumManager = new Proxy(address(oracleQuorumManager), address(admin), "");
        Proxy proxyReturnsAggregator = new Proxy(address(returnsAggregator), address(admin), "");
        Proxy proxyReturnsReceiver = new Proxy(address(returnsReceiver), address(admin), "");
        Proxy proxyStakingManager = new Proxy(address(stakingManager), address(admin), "");
        Proxy proxyUnstakeRequestsManager = new Proxy(address(unstakeRequestsManager), address(admin), "");


        //====================== initialize ======================
        {
            L1Pauser.Init memory initInfo = L1Pauser.Init({
                admin: msg.sender,
                pauser: msg.sender,
                unpauser: msg.sender,
                oracle: oracleManager
             });
            L1Pauser(address(proxyDappLinkPauser)).initialize(initInfo);
        }

        {
            DETH.Init memory initDeth = DETH.Init({
                admin: msg.sender,
                l2ShareAddress: msg.sender,
                staking: stakingManager,
                unstakeRequestsManager: unstakeRequestsManager
            });
            DETH(address(proxyDETH)).initialize(initDeth);
        }

        {
            OracleManager.Init memory initOracle = OracleManager.Init({
                admin: msg.sender,
                manager: msg.sender,
                oracleUpdater: msg.sender,
                pendingResolver: msg.sender,
                aggregator: returnsAggregator,
                pauser: dappLinkPauser,
                staking: stakingManager
            });
            OracleManager(address(proxyOracleManager)).initialize(initOracle);
        }

        {
            address[] memory allowedReporters = new address[](1);
            allowedReporters[0] = msg.sender;
            OracleQuorumManager.Init memory initOracleQuorumManager = OracleQuorumManager.Init({
                admin: msg.sender,
                reporterModifier: msg.sender,
                manager: msg.sender,
                allowedReporters: allowedReporters,
                oracle: oracleManager
            });
            OracleQuorumManager(address(proxyOracleQuorumManager)).initialize(initOracleQuorumManager);
        }

        {
            ReturnsAggregator.Init memory initReturnsAggregator = ReturnsAggregator.Init({
                admin: msg.sender,
                manager: msg.sender,
                oracle: oracleManager,
                pauser: dappLinkPauser,
                consensusLayerReceiver: returnsReceiver,
                executionLayerReceiver: returnsReceiver,
                staking: stakingManager,
                feesReceiver: payable(msg.sender)
            });
            ReturnsAggregator(payable(address(proxyReturnsAggregator))).initialize(initReturnsAggregator);
        }


        {
            ReturnsReceiver.Init memory initReturnsReceiver = ReturnsReceiver.Init({
                admin: msg.sender,
                manager: msg.sender,
                withdrawer: msg.sender
            });
            ReturnsReceiver(payable(address(proxyReturnsReceiver))).initialize(initReturnsReceiver);
         }


         {
            StakingManager.Init memory initStakingManager = StakingManager.Init({
                admin: msg.sender,
                manager: msg.sender,
                allocatorService: msg.sender,
                initiatorService: msg.sender,
                returnsAggregator: msg.sender,
                withdrawalWallet: msg.sender,
                dapplinkBridge: msg.sender,
                dETH: dETH,
                depositContract: IDepositContract(address(msg.sender)),
                oracle: oracleManager,
                pauser: dappLinkPauser,
                unstakeRequestsManager: unstakeRequestsManager
            });
            StakingManager(payable(address(proxyStakingManager))).initialize(initStakingManager);
         }

         {
            UnstakeRequestsManager.Init memory initUnstakeRequestsManager = UnstakeRequestsManager.Init({
                admin: msg.sender,
                manager: msg.sender,
                requestCanceller: msg.sender,
                dETH: dETH,
                stakingContract: stakingManager,
                oracle: oracleManager,
                numberOfBlocksToFinalize: 64
            });
            UnstakeRequestsManager(payable(address(proxyUnstakeRequestsManager))).initialize(initUnstakeRequestsManager);
        }

        vm.writeFile("data/proxyDappLinkPauser.addr", vm.toString(address(proxyDappLinkPauser)));
        vm.writeFile("data/proxyDETH.addr", vm.toString(address(proxyDETH)));
        vm.writeFile("data/proxyOracleManager.addr", vm.toString(address(proxyOracleManager)));
        vm.writeFile("data/proxyOracleQuorumManager.addr", vm.toString(address(proxyOracleQuorumManager)));
        vm.writeFile("data/proxyReturnsAggregator.addr", vm.toString(address(proxyReturnsAggregator)));
        vm.writeFile("data/proxyReturnsReceiver.addr", vm.toString(address(proxyReturnsReceiver)));
        vm.writeFile("data/proxyStakingManager.addr", vm.toString(address(proxyStakingManager)));
        vm.writeFile("data/proxyUnstakeRequestsManager.addr", vm.toString(address(proxyUnstakeRequestsManager)));

        vm.stopBroadcast();
    }
}