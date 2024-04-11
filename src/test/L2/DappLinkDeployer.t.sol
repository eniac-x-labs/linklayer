// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "@/contracts/L2/core/DelegationManager.sol";
import "@/contracts/L2/core/L1RewardManager.sol";
import "@/contracts/L2/core/L2RewardManager.sol";
import "@/contracts/L2/core/StrategyManager.sol";
import "@/contracts/L2/strategies/StrategyBase.sol";

import "@/contracts/L2/core/SlashManager.sol";

import "@/contracts/access/L2Pauser.sol";

import "@/contracts/access/proxy/Proxy.sol";


import "@/test/DappLinkToken.sol";


import "forge-std/Test.sol";



contract DappLinkDeployer is Test {
    ProxyAdmin        public dappLinkProxyAdmin;
    DelegationManager public delegationManager;
    L1RewardManager   public l1RewardManager;
    L2RewardManager   public l2RewardManager;
    StrategyManager   public strategyManager;
    StrategyBase      public socialStrategy;
    StrategyBase      public gamingStrategy;
    StrategyBase      public daStrategy;
    SlashManager      public slashManager;
    L2Pauser          public dappLinkPauser;
    DappLinkToken     public dappLinkToken;

    Proxy             public proxyDappLinkPauser;
    Proxy public proxyDelegationManager;
    Proxy public proxySlashManager;
    Proxy public proxyL1RewardManager;
    Proxy public proxyL2RewardManager;
    Proxy public proxyStrategyManager;
    Proxy public proxySocialStrategy;
    Proxy public proxyGamingStrategy;
    Proxy public proxyDaStrategy;
    Proxy public proxyDappLinkToken;

    function run() external {
        vm.startBroadcast();
        address admin = msg.sender;
        address relayer = msg.sender;

        dappLinkProxyAdmin = new ProxyAdmin(msg.sender);
        dappLinkPauser = new L2Pauser();
        delegationManager = new DelegationManager();
        slashManager = new SlashManager();
        l1RewardManager = new L1RewardManager();
        l2RewardManager = new L2RewardManager();
        strategyManager = new StrategyManager();
        socialStrategy = new StrategyBase();
        gamingStrategy = new StrategyBase();
        daStrategy = new StrategyBase();
        dappLinkToken = new DappLinkToken();


        //====================== deploy ======================
        proxyDappLinkPauser = new Proxy(address(dappLinkPauser), address(admin), "");
        proxyDelegationManager = new Proxy(address(delegationManager), address(admin), "");
        proxySlashManager = new Proxy(address(slashManager), address(admin), "");
        proxyL1RewardManager = new Proxy(address(l1RewardManager), address(admin), "");
        proxyL2RewardManager = new Proxy(address(l2RewardManager), address(admin), "");
        proxyStrategyManager = new Proxy(address(strategyManager), address(admin), "");
        proxySocialStrategy = new Proxy(address(socialStrategy), address(admin), "");
        proxyGamingStrategy = new Proxy(address(gamingStrategy), address(admin), "");
        proxyDaStrategy = new Proxy(address(daStrategy), address(admin), "");
        proxyDappLinkToken = new Proxy(address(dappLinkToken), address(admin), "");


        //====================== initialize ======================
        DappLinkToken(address(proxyDappLinkToken)).initialize(address(admin));

        {
            L2Pauser.Init memory initInfo = L2Pauser.Init({
                admin: msg.sender,
                pauser: msg.sender,
                unpauser: msg.sender
             });
            L2Pauser(address(proxyDappLinkPauser)).initialize(initInfo);
            L2Pauser(address(proxyDappLinkPauser)).unpauseAll();
        }

        {
            IStrategy[] memory _strategies = new IStrategy[](3);
            _strategies[0] = IStrategy(address(proxySocialStrategy));
            _strategies[1] = IStrategy(address(proxyGamingStrategy));
            _strategies[2] = IStrategy(address(proxyDaStrategy));
             uint256[] memory _withdrawalDelayBlocks = new uint256[](3);
             _withdrawalDelayBlocks[0]= 10;
             _withdrawalDelayBlocks[1]= 10;
             _withdrawalDelayBlocks[2]= 10;
             uint256 _minWithdrawalDelayBlocks = 5;
             DelegationManager(address(proxyDelegationManager)).initialize(address(admin), _minWithdrawalDelayBlocks, _strategies, _withdrawalDelayBlocks, IStrategyManager(address(proxyStrategyManager)), ISlashManager(address(slashManager)), dappLinkPauser);
        }

        SlashManager(address(proxySlashManager)).initialize(address(admin));

        L1RewardManager(address(proxyL1RewardManager)).initialize(address(admin));

        {
            address dappLinkAddr = address(0xB8c77482e45F1F44dE1745F52C74426C631bDD52);
            IERC20 dappLinkToken = IERC20(dappLinkAddr);
            L2RewardManager(address(proxyL2RewardManager)).initialize(address(admin), IDelegationManager(address(delegationManager)), IStrategyManager(address(proxyStrategyManager)), dappLinkToken);
        }

        {
            address initialStrategyWhitelister = msg.sender;
            StrategyManager(address(proxyStrategyManager)).initialize(address(admin), initialStrategyWhitelister, relayer, IDelegationManager(address(delegationManager)), ISlashManager(address(slashManager)), dappLinkPauser);
        }

        {
            StrategyBase(address(proxySocialStrategy)).initialize(IERC20(address(proxyDappLinkToken)), relayer, IStrategyManager(address(proxyStrategyManager)), dappLinkPauser);
            StrategyBase(address(proxyGamingStrategy)).initialize(IERC20(address(proxyDappLinkToken)), relayer, IStrategyManager(address(proxyStrategyManager)), dappLinkPauser);
            StrategyBase(address(proxyDaStrategy)).initialize(IERC20(address(proxyDappLinkToken)), relayer, IStrategyManager(address(proxyStrategyManager)), dappLinkPauser);
        }

        vm.stopBroadcast();
    }
}