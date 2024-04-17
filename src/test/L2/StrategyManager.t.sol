// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import "@/contracts/L2/core/DelegationManager.sol";
// import "@/contracts/L2/core/L1RewardManager.sol";
import {L2RewardManager}  from "@/contracts/L2/core/L2RewardManager.sol";
import "@/contracts/L2/core/StrategyManager.sol";
import "@/contracts/L2/strategies/StrategyBase.sol";

import "@/contracts/L2/core/SlashManager.sol";

import "@/contracts/access/L2Pauser.sol";

import "@/contracts/access/proxy/Proxy.sol";


import "@/test/DappLinkToken.sol";


import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {L2Test} from "./L2Test.t.sol";


contract StrategyManagerTest is L2Test {
    function testDeposit() public {
        StrategyManager(address(proxyStrategyManager)).depositETHIntoStrategy{value: 0.1 ether}(address(proxySocialStrategy));
    }
}