// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "@/contracts/L1/core/DETH.sol";
import "@/contracts/L1/core/OracleManager.sol";
import "@/contracts/L1/core/OracleQuorumManager.sol";
import "@/contracts/L1/core/ReturnsAggregator.sol";
import "@/contracts/L1/core/ReturnsReceiver.sol";
import  "@/contracts/L1/core/StakingManager.sol";
import "@/contracts/L1/core/UnstakeRequestsManager.sol";

import "@/contracts/access/L1Pauser.sol";

import "@/contracts/access/proxy/Proxy.sol";
import "@/contracts/L1/core/L1Locator.sol";
import "@/contracts/L1/interfaces/IDepositContract.sol";

import "forge-std/Test.sol";
contract L1Test is Test {
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

    Proxy proxyDappLinkPauser;
    Proxy proxyDETH;
    Proxy proxyOracleManager;
    Proxy proxyOracleQuorumManager;
    Proxy proxyReturnsAggregator;
    Proxy proxyConsensusLayerReceiver;
    Proxy proxyExecutionLayerReceiver;
    Proxy proxyStakingManager;
    Proxy proxyUnstakeRequestsManager;

    function setUp() external {
        address admin = msg.sender;
        vm.deal(admin, 1000 ether);
        vm.startPrank(admin);
        // vm.startBroadcast();
        address depositAddress = 0x4242424242424242424242424242424242424242; // holesky testnet
        address dapplinkBridge = msg.sender; // holesky testnet
        dappLinkProxyAdmin = new ProxyAdmin(admin);
        dappLinkPauser = new L1Pauser();
        dETH = new DETH();
        oracleManager = new OracleManager();
        oracleQuorumManager = new OracleQuorumManager();
        returnsAggregator = new ReturnsAggregator();
        returnsReceiver = new ReturnsReceiver();
        stakingManager = new StakingManager();
        unstakeRequestsManager = new UnstakeRequestsManager();

        proxyDappLinkPauser = new Proxy(address(dappLinkPauser), address(admin), "");
        proxyDETH = new Proxy(address(dETH), address(admin), "");
        proxyOracleManager = new Proxy(address(oracleManager), address(admin), "");
        proxyOracleQuorumManager = new Proxy(address(oracleQuorumManager), address(admin), "");
        proxyReturnsAggregator = new Proxy(address(returnsAggregator), address(admin), "");
        proxyConsensusLayerReceiver = new Proxy(address(returnsReceiver), address(admin), "");
        proxyExecutionLayerReceiver = new Proxy(address(returnsReceiver), address(admin), "");
        proxyStakingManager = new Proxy(address(stakingManager), address(admin), "");
        proxyUnstakeRequestsManager = new Proxy(address(unstakeRequestsManager), address(admin), "");


        
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
                admin: admin,
                pauser: admin,
                unpauser: admin,
                oracle: IOracleManager(address(proxyOracleManager))
             });
            L1Pauser(address(proxyDappLinkPauser)).initialize(initInfo);
            L1Pauser(address(proxyDappLinkPauser)).unpauseAll();
        }

        {
            DETH.Init memory initDeth = DETH.Init({
                admin: admin,
                l2ShareAddress: admin,
                bridgeAddress: msg.sender
            });
            DETH(address(proxyDETH)).initialize(initDeth);
            DETH(address(proxyDETH)).setLocator(address(l1Locator));
        }

        {
            address[] memory allowedReporters = new address[](1);
            allowedReporters[0] = admin;
            OracleQuorumManager.Init memory initOracleQuorumManager = OracleQuorumManager.Init({
                admin: admin,
                reporterModifier: admin,
                manager: admin,
                allowedReporters: allowedReporters
            });
            OracleQuorumManager(address(proxyOracleQuorumManager)).initialize(initOracleQuorumManager);
            OracleQuorumManager(address(proxyOracleQuorumManager)).setLocator(address(l1Locator));
        }

         {
            ReturnsReceiver.Init memory initReturnsReceiver = ReturnsReceiver.Init({
                admin: admin,
                manager: admin,
                withdrawer: admin
            });
            ReturnsReceiver(payable(address(proxyConsensusLayerReceiver))).initialize(initReturnsReceiver);
            ReturnsReceiver(payable(address(proxyExecutionLayerReceiver))).initialize(initReturnsReceiver);

            ReturnsReceiver(payable(address(proxyConsensusLayerReceiver))).setLocator(address(l1Locator));

            ReturnsReceiver(payable(address(proxyExecutionLayerReceiver))).setLocator(address(l1Locator));
         }

        {
            ReturnsAggregator.Init memory initReturnsAggregator = ReturnsAggregator.Init({
                admin: admin,
                manager: admin,
                feesReceiver: payable(admin)
            });
            ReturnsAggregator(payable(address(proxyReturnsAggregator))).initialize(initReturnsAggregator);
            ReturnsAggregator(payable(address(proxyReturnsAggregator))).setLocator(address(l1Locator));
        }

        {
            StakingManager.Init memory initStakingManager = StakingManager.Init({
                admin: admin,
                manager: admin,
                allocatorService: admin,
                initiatorService: admin,
                withdrawalWallet: address(proxyConsensusLayerReceiver)
            });
            StakingManager(payable(address(proxyStakingManager))).initialize(initStakingManager);
            StakingManager(payable(address(proxyStakingManager))).setLocator(address(l1Locator));
            // StakingManager(payable(address(proxyStakingManager))).stake{value:32 ether}(32000000000000000000);
         }

         {
            UnstakeRequestsManager.Init memory initUnstakeRequestsManager = UnstakeRequestsManager.Init({
                admin: admin,
                manager: admin,
                requestCanceller: admin,
                numberOfBlocksToFinalize: 64
            });
            UnstakeRequestsManager(payable(address(proxyUnstakeRequestsManager))).initialize(initUnstakeRequestsManager);
            UnstakeRequestsManager(payable(address(proxyUnstakeRequestsManager))).setLocator(address(l1Locator));
        }


        {
            OracleManager.Init memory initOracle = OracleManager.Init({
                admin: admin,
                manager: admin,
                oracleUpdater: admin,
                pendingResolver: admin
            });
            OracleManager(address(proxyOracleManager)).initialize(initOracle);
            OracleManager(address(proxyOracleManager)).setLocator(address(l1Locator));

            OracleManager(address(proxyOracleManager)).initRecord();

        }


        

        // vm.writeFile("data/L1/proxyDappLinkPauser.addr", vm.toString(address(proxyDappLinkPauser)));
        // vm.writeFile("data/L1/proxyDETH.addr", vm.toString(address(proxyDETH)));
        // vm.writeFile("data/L1/proxyOracleManager.addr", vm.toString(address(proxyOracleManager)));
        // vm.writeFile("data/L1/proxyOracleQuorumManager.addr", vm.toString(address(proxyOracleQuorumManager)));
        // vm.writeFile("data/L1/proxyReturnsAggregator.addr", vm.toString(address(proxyReturnsAggregator)));
        // vm.writeFile("data/L1/proxyConsensusLayerReceiver.addr", vm.toString(address(proxyConsensusLayerReceiver)));
        // vm.writeFile("data/L1/proxyExecutionLayerReceiver.addr", vm.toString(address(proxyExecutionLayerReceiver)));
        // vm.writeFile("data/L1/proxyStakingManager.addr", vm.toString(address(proxyStakingManager)));
        // vm.writeFile("data/L1/proxyUnstakeRequestsManager.addr", vm.toString(address(proxyUnstakeRequestsManager)));

        // vm.stopBroadcast();
    }

    
    // function testBatchMintDEth()public{
    //     address admin = 0x2822E13eF080475e8CaBe39b3dc65c6dbe9b083a
    //     vm.startPrank(admin);
    //     IDETH.BatchMint memory dm = IDETH.BatchMint({staker:admin,amount:32000000000000000000});
    //     IDETH.BatchMint[] memory mints = new IDETH.BatchMint[](1);
    //     mints[0] = dm;

    //     dETH.batchMint(mints);
    // }
}
