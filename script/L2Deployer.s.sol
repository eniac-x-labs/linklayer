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

import "@/contracts/access/PauserRegistry.sol";

import "../src/contracts/access/proxy/Proxy.sol";


import "forge-std/Script.sol";



// forge script script/L2Deployer.s.sol:L2Deployer --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv
contract L2Deployer is Script {
    ProxyAdmin        public dappLinkProxyAdmin;
    DelegationManager public delegationManager;
    L1RewardManager   public l1RewardManager;
    L2RewardManager   public l2RewardManager;
    StrategyManager   public strategyManager;
    StrategyBase      public socialStrategy;
    StrategyBase      public gamingStrategy;
    StrategyBase      public daStrategy;
    SlashManager      public slashManager;

    IPauserRegistry public dappLinkPauserReg;
    address[] pausers;

    function run() external {
        vm.startBroadcast();

        pausers.push(msg.sender);
        address unpauser = msg.sender;
        address dappLinkMultisig = msg.sender;
        address admin = msg.sender;

        dappLinkProxyAdmin = new ProxyAdmin(msg.sender);
        dappLinkPauserReg = new PauserRegistry(pausers, unpauser);

        uint256 initialPausedStatus = 0;

        delegationManager = new DelegationManager();
        slashManager = new SlashManager();
        l1RewardManager = new L1RewardManager();
        l2RewardManager = new L2RewardManager();
        strategyManager = new StrategyManager();
        socialStrategy = new StrategyBase();
        gamingStrategy = new StrategyBase();
        daStrategy = new StrategyBase();


        //====================== deploy ======================
        Proxy proxyDelegationManager = new Proxy(address(delegationManager), address(admin), "");
        Proxy proxySlashManager = new Proxy(address(slashManager), address(admin), "");
        Proxy proxyL1RewardManager = new Proxy(address(l1RewardManager), address(admin), "");
        Proxy proxyL2RewardManager = new Proxy(address(l2RewardManager), address(admin), "");
        Proxy proxyStrategyManager = new Proxy(address(strategyManager), address(admin), "");
        Proxy proxySocialStrategy = new Proxy(address(socialStrategy), address(admin), "");
        Proxy proxyGamingStrategy = new Proxy(address(gamingStrategy), address(admin), "");
        Proxy proxyDaStrategy = new Proxy(address(daStrategy), address(admin), "");


        //====================== initialize ======================
         {
            IStrategy[] memory _strategies = new IStrategy[](3);
            _strategies[0] = IStrategy(address(socialStrategy));
            _strategies[1] = IStrategy(address(gamingStrategy));
            _strategies[2] = IStrategy(address(daStrategy));
             uint256[] memory _withdrawalDelayBlocks = new uint256[](3);
             _withdrawalDelayBlocks[0]= 10;
             _withdrawalDelayBlocks[1]= 10;
             _withdrawalDelayBlocks[2]= 10;
             uint256 _minWithdrawalDelayBlocks = 5;
             DelegationManager(address(proxyDelegationManager)).initialize(address(admin), dappLinkPauserReg, initialPausedStatus, _minWithdrawalDelayBlocks, _strategies, _withdrawalDelayBlocks, strategyManager, slashManager);
        }

        SlashManager(address(proxySlashManager)).initialize(address(admin));

        L1RewardManager(address(proxyL1RewardManager)).initialize(address(admin), strategyManager);

        L2RewardManager(address(proxyL2RewardManager)).initialize(address(admin));

        {
            address initialStrategyWhitelister = msg.sender;
            StrategyManager(address(proxyStrategyManager)).initialize(address(admin), initialStrategyWhitelister, dappLinkPauserReg, initialPausedStatus, delegationManager, slashManager);
        }

        {
            address WethAddress = address(0xB8c77482e45F1F44dE1745F52C74426C631bDD52);
            IERC20 underlyingToken = IERC20(WethAddress);

            StrategyBase(address(proxySocialStrategy)).initialize(underlyingToken, dappLinkPauserReg, strategyManager);
            StrategyBase(address(proxyGamingStrategy)).initialize(underlyingToken, dappLinkPauserReg, strategyManager);
            StrategyBase(address(proxyDaStrategy)).initialize(underlyingToken, dappLinkPauserReg, strategyManager);
        }

        vm.stopBroadcast();
    }
}