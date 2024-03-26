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

import "../src/contracts/access/proxy/Proxy.sol";


import "forge-std/Script.sol";



// forge script script/L2Deployer.s.sol:L2Deployer --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv --legacy --gas-price 1000000000
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
    L2Pauser          public dappLinkPauser;

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


        //====================== deploy ======================
        Proxy proxyDappLinkPauser = new Proxy(address(dappLinkPauser), address(admin), "");
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
            L2Pauser.Init memory initInfo = L2Pauser.Init({
                admin: msg.sender,
                pauser: msg.sender,
                unpauser: msg.sender
             });
            L2Pauser(address(proxyDappLinkPauser)).initialize(initInfo);
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

        L1RewardManager(address(proxyL1RewardManager)).initialize(address(admin), IStrategyManager(address(proxyStrategyManager)));

        {
            address dappLinkAddr = address(0xB8c77482e45F1F44dE1745F52C74426C631bDD52);
            IERC20 dappLinkToken = IERC20(dappLinkAddr);
            L2RewardManager(address(proxyL2RewardManager)).initialize(address(admin), IDelegationManager(address(delegationManager)), IStrategyManager(address(proxyStrategyManager)), dappLinkToken);
        }

        {
            address initialStrategyWhitelister = msg.sender;
            StrategyManager(address(proxyStrategyManager)).initialize(address(admin), initialStrategyWhitelister, IDelegationManager(address(delegationManager)), ISlashManager(address(slashManager)), dappLinkPauser);
        }

        {
            address WethAddress = address(0xB8c77482e45F1F44dE1745F52C74426C631bDD52);
            IERC20 underlyingToken = IERC20(WethAddress);
            StrategyBase(address(proxySocialStrategy)).initialize(underlyingToken, relayer, IStrategyManager(address(proxyStrategyManager)), dappLinkPauser);
            StrategyBase(address(proxyGamingStrategy)).initialize(underlyingToken, relayer, IStrategyManager(address(proxyStrategyManager)), dappLinkPauser);
            StrategyBase(address(proxyDaStrategy)).initialize(underlyingToken, relayer, IStrategyManager(address(proxyStrategyManager)), dappLinkPauser);
        }

        vm.writeFile("data/L2/proxyDelegationManager.addr", vm.toString(address(proxyDelegationManager)));
        vm.writeFile("data/L2/proxySlashManager.addr", vm.toString(address(proxySlashManager)));
        vm.writeFile("data/L2/proxyL1RewardManager.addr", vm.toString(address(proxyL1RewardManager)));
        vm.writeFile("data/L2/proxyL2RewardManager.addr", vm.toString(address(proxyL2RewardManager)));
        vm.writeFile("data/L2/proxyStrategyManager.addr", vm.toString(address(proxyStrategyManager)));
        vm.writeFile("data/L2/proxySocialStrategy.addr", vm.toString(address(proxySocialStrategy)));
        vm.writeFile("data/L2/proxyGamingStrategy.addr", vm.toString(address(proxyGamingStrategy)));
        vm.writeFile("data/L2/proxyDaStrategy.addr", vm.toString(address(proxyDaStrategy)));


        vm.stopBroadcast();
    }
}