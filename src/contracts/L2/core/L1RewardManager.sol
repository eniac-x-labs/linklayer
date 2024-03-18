// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IStrategyManager.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IL1RewardManager.sol";

contract L1RewardManager is IL1RewardManager, Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    uint256 public L1RewardBalance;

    IStrategyManager public immutable strategyManager;
    IStrategy public immutable strategy;

    constructor(IStrategyManager _strategyManager, IStrategy _strategy){
        strategyManager = _strategyManager;
        strategy = _strategy;
    }

    function depositETHRewardTo() external payable returns (bool) {
        payable(address(this)).transfer(msg.value);
        L1RewardBalance += msg.value;
        emit DepositETHRewardTo(msg.sender, msg.value);
        return true;
    }

    function claimL1Reward() external payable returns (bool) {
        uint256 shares = strategy.totalShares();
        uint256 userShares = 0;
        uint256 strategyLength = strategyManager.stakerStrategyListLength(msg.sender);
        for (uint256 i = 0; i < strategyLength; i++) {
            userShares += strategy.shares(msg.sender);
        }
        uint256 amountToSend = L1RewardBalance * (userShares / shares);
        payable(msg.sender).transfer(amountToSend);
        emit ClaimL1Reward(msg.sender, amountToSend);
        return true;
    }
}
