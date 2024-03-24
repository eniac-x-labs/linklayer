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

import "@/contracts/access/Pauser.sol";

import "../src/contracts/access/proxy/Proxy.sol";


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
    Pauser                 public dappLinkPauser;

    function run() external {
        vm.startBroadcast();

        address dappLinkMultisig = msg.sender;
        address admin = msg.sender;
        address relayer = msg.sender;

        dappLinkProxyAdmin = new ProxyAdmin(msg.sender);
        dappLinkPauser = new Pauser();
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