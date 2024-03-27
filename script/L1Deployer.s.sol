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

    function run() external {
        vm.startBroadcast();
        address admin = msg.sender;

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
                oracle: IOracleManager(address(proxyOracleManager))
             });
            L1Pauser(address(proxyDappLinkPauser)).initialize(initInfo);
        }

        {
            DETH.Init memory initDeth = DETH.Init({
                admin: msg.sender,
                l2ShareAddress: msg.sender,
                staking: IStakingManager(address(proxyStakingManager)),
                unstakeRequestsManager: IUnstakeRequestsManager(address(proxyUnstakeRequestsManager))
            });
            DETH(address(proxyDETH)).initialize(initDeth);
        }

        {
            address[] memory allowedReporters = new address[](1);
            allowedReporters[0] = msg.sender;
            OracleQuorumManager.Init memory initOracleQuorumManager = OracleQuorumManager.Init({
                admin: msg.sender,
                reporterModifier: msg.sender,
                manager: msg.sender,
                allowedReporters: allowedReporters,
                oracle: IOracleManager(address(proxyOracleManager))
            });
            OracleQuorumManager(address(proxyOracleQuorumManager)).initialize(initOracleQuorumManager);
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
            ReturnsAggregator.Init memory initReturnsAggregator = ReturnsAggregator.Init({
                admin: msg.sender,
                manager: msg.sender,
                oracle: IOracleManager(address(proxyOracleManager)),
                pauser: dappLinkPauser,
                consensusLayerReceiver: ReturnsReceiver(payable(address(proxyReturnsReceiver))),
                executionLayerReceiver: ReturnsReceiver(payable(address(proxyReturnsReceiver))),
                staking: IStakingManager(address(proxyStakingManager)),
                feesReceiver: payable(msg.sender)
            });
            ReturnsAggregator(payable(address(proxyReturnsAggregator))).initialize(initReturnsAggregator);
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
                dETH: IDETH(address(proxyDETH)),
                depositContract: IDepositContract(address(msg.sender)),
                oracle: IOracleManager(address(proxyOracleManager)),
                pauser: IL1Pauser(address(proxyDappLinkPauser)),
                unstakeRequestsManager: unstakeRequestsManager
            });
            StakingManager(payable(address(proxyStakingManager))).initialize(initStakingManager);
         }

         {
            UnstakeRequestsManager.Init memory initUnstakeRequestsManager = UnstakeRequestsManager.Init({
                admin: msg.sender,
                manager: msg.sender,
                requestCanceller: msg.sender,
                dETH: IDETH(address(proxyDETH)),
                stakingContract: IStakingManager(address(proxyStakingManager)),
                oracle: IOracleManager(address(proxyOracleManager)),
                numberOfBlocksToFinalize: 64
            });
            UnstakeRequestsManager(payable(address(proxyUnstakeRequestsManager))).initialize(initUnstakeRequestsManager);
        }


        {
            OracleManager.Init memory initOracle = OracleManager.Init({
                admin: msg.sender,
                manager: msg.sender,
                oracleUpdater: msg.sender,
                pendingResolver: msg.sender,
                aggregator: IReturnsAggregator(address(proxyReturnsAggregator)),
                pauser: IL1Pauser(address(proxyDappLinkPauser)),
                staking: IStakingManager(address(proxyStakingManager))
            });
            OracleManager(address(proxyOracleManager)).initialize(initOracle);
        }

        vm.writeFile("data/L1/proxyDappLinkPauser.addr", vm.toString(address(proxyDappLinkPauser)));
        vm.writeFile("data/L1/proxyDETH.addr", vm.toString(address(proxyDETH)));
        vm.writeFile("data/L1/proxyOracleManager.addr", vm.toString(address(proxyOracleManager)));
        vm.writeFile("data/L1/proxyOracleQuorumManager.addr", vm.toString(address(proxyOracleQuorumManager)));
        vm.writeFile("data/L1/proxyReturnsAggregator.addr", vm.toString(address(proxyReturnsAggregator)));
        vm.writeFile("data/L1/proxyReturnsReceiver.addr", vm.toString(address(proxyReturnsReceiver)));
        vm.writeFile("data/L1/proxyStakingManager.addr", vm.toString(address(proxyStakingManager)));
        vm.writeFile("data/L1/proxyUnstakeRequestsManager.addr", vm.toString(address(proxyUnstakeRequestsManager)));

        vm.stopBroadcast();
    }
}