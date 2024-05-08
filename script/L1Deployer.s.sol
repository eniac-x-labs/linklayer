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
import "@/contracts/L1/core/L1Locator.sol";
import "../src/contracts/access/proxy/Proxy.sol";

import "@/contracts/L1/interfaces/IDepositContract.sol";


import "forge-std/Script.sol";

// forge script script/L1Deployer.s.sol:L1Deployer --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv --legacy --gas-price 1000000000
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
    L1Locator              public l1Locator;


    function run() external {
        vm.startBroadcast();
        address admin = msg.sender;
        address depositAddress = 0x4242424242424242424242424242424242424242; // holesky testnet
        address dapplinkBridge = 0x78de729757Ef7C48c76C9EEe35B38Cc7108d59ca; // holesky testnet
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
        Proxy proxyConsensusLayerReceiver = new Proxy(address(returnsReceiver), address(admin), "");
        Proxy proxyExecutionLayerReceiver = new Proxy(address(returnsReceiver), address(admin), "");
        Proxy proxyStakingManager = new Proxy(address(stakingManager), address(admin), "");
        Proxy proxyUnstakeRequestsManager = new Proxy(address(unstakeRequestsManager), address(admin), "");


        L1Locator.Config memory _config = L1Locator.Config({
            stakingManager: address(proxyStakingManager),
            unStakingRequestsManager: address(proxyUnstakeRequestsManager),
            dETH: address(proxyDETH),
            pauser: address(proxyDappLinkPauser),
            returnsAggregator: address(proxyReturnsAggregator),
            oracleManager: address(proxyOracleManager),
            oracleQuorumManager: address(proxyOracleQuorumManager),
            consensusLayerReceiver: address(proxyConsensusLayerReceiver),
            executionLayerReceiver: address(proxyExecutionLayerReceiver),
            dapplinkBridge: dapplinkBridge,
            depositContract: depositAddress,
            relayerAddress: msg.sender
        });
        l1Locator = new L1Locator(_config);
        //====================== initialize ======================
        {
            L1Pauser.Init memory initInfo = L1Pauser.Init({
                admin: msg.sender,
                pauser: msg.sender,
                unpauser: msg.sender,
                oracle: IOracleManager(address(proxyOracleManager))
             });
            L1Pauser(address(proxyDappLinkPauser)).initialize(initInfo);
            L1Pauser(address(proxyDappLinkPauser)).unpauseAll();
        }

        {
            DETH.Init memory initDeth = DETH.Init({
                admin: msg.sender,
                l2ShareAddress: msg.sender,
                bridgeAddress: msg.sender
            });
            DETH(address(proxyDETH)).initialize(initDeth);
            DETH(address(proxyDETH)).setLocator(address(l1Locator));
        }

        {
            address[] memory allowedReporters = new address[](1);
            allowedReporters[0] = msg.sender;
            OracleQuorumManager.Init memory initOracleQuorumManager = OracleQuorumManager.Init({
                admin: msg.sender,
                reporterModifier: msg.sender,
                manager: msg.sender,
                allowedReporters: allowedReporters
            });
            OracleQuorumManager(address(proxyOracleQuorumManager)).initialize(initOracleQuorumManager);
            OracleQuorumManager(address(proxyOracleQuorumManager)).setLocator(address(l1Locator));
        }

         {
            ReturnsReceiver.Init memory initReturnsReceiver = ReturnsReceiver.Init({
                admin: msg.sender,
                manager: msg.sender,
                withdrawer: msg.sender
            });
            ReturnsReceiver(payable(address(proxyConsensusLayerReceiver))).initialize(initReturnsReceiver);
            
            ReturnsReceiver(payable(address(proxyExecutionLayerReceiver))).initialize(initReturnsReceiver);

            ReturnsReceiver(payable(address(proxyConsensusLayerReceiver))).setLocator(address(l1Locator));

            ReturnsReceiver(payable(address(proxyExecutionLayerReceiver))).setLocator(address(l1Locator));
         }

        {
            ReturnsAggregator.Init memory initReturnsAggregator = ReturnsAggregator.Init({
                admin: msg.sender,
                manager: msg.sender,
                feesReceiver: payable(msg.sender)
            });
            ReturnsAggregator(payable(address(proxyReturnsAggregator))).initialize(initReturnsAggregator);
            ReturnsAggregator(payable(address(proxyReturnsAggregator))).setLocator(address(l1Locator));
        }

        {
            StakingManager.Init memory initStakingManager = StakingManager.Init({
                admin: msg.sender,
                manager: msg.sender,
                allocatorService: msg.sender,
                initiatorService: msg.sender,
                withdrawalWallet: address(proxyConsensusLayerReceiver)
            });
            StakingManager(payable(address(proxyStakingManager))).initialize(initStakingManager);
            StakingManager(payable(address(proxyStakingManager))).setLocator(address(l1Locator));
            // StakingManager(payable(address(proxyStakingManager))).stake{value:32 ether}(32000000000000000000);
         }

         {
            UnstakeRequestsManager.Init memory initUnstakeRequestsManager = UnstakeRequestsManager.Init({
                admin: msg.sender,
                manager: msg.sender,
                requestCanceller: msg.sender,
                numberOfBlocksToFinalize: 64
            });
            UnstakeRequestsManager(payable(address(proxyUnstakeRequestsManager))).initialize(initUnstakeRequestsManager);
            UnstakeRequestsManager(payable(address(proxyUnstakeRequestsManager))).setLocator(address(l1Locator));
        }


        {
            OracleManager.Init memory initOracle = OracleManager.Init({
                admin: msg.sender,
                manager: msg.sender,
                oracleUpdater: msg.sender,
                pendingResolver: msg.sender
            });
            OracleManager(address(proxyOracleManager)).initialize(initOracle);
            OracleManager(address(proxyOracleManager)).setLocator(address(l1Locator));
            OracleManager(address(proxyOracleManager)).initRecord();
        }


        
        vm.writeFile("data/L1/locator.addr", vm.toString(address(proxyDETH)));
        vm.writeFile("data/L1/proxyDappLinkPauser.addr", vm.toString(address(proxyDappLinkPauser)));
        vm.writeFile("data/L1/proxyDETH.addr", vm.toString(address(proxyDETH)));
        vm.writeFile("data/L1/proxyOracleManager.addr", vm.toString(address(proxyOracleManager)));
        vm.writeFile("data/L1/proxyOracleQuorumManager.addr", vm.toString(address(proxyOracleQuorumManager)));
        vm.writeFile("data/L1/proxyReturnsAggregator.addr", vm.toString(address(proxyReturnsAggregator)));
        vm.writeFile("data/L1/proxyConsensusLayerReceiver.addr", vm.toString(address(proxyConsensusLayerReceiver)));
        vm.writeFile("data/L1/proxyExecutionLayerReceiver.addr", vm.toString(address(proxyExecutionLayerReceiver)));
        vm.writeFile("data/L1/proxyStakingManager.addr", vm.toString(address(proxyStakingManager)));
        vm.writeFile("data/L1/proxyUnstakeRequestsManager.addr", vm.toString(address(proxyUnstakeRequestsManager)));

        vm.stopBroadcast();
    }
}