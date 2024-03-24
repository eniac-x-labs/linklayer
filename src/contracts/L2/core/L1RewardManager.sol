// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IStrategyManager.sol";
import "../interfaces/IL1RewardManager.sol";

contract L1RewardManager is IL1RewardManager, Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    uint256 public L1RewardBalance;

    IStrategyManager public strategyManager;

    constructor(){
       _disableInitializers();
    }

    function initialize(
        address initialOwner,
        IStrategyManager _strategyManager
    ) external initializer {
        _transferOwnership(initialOwner);
         strategyManager = _strategyManager;
    }

    function depositETHRewardTo() external payable returns (bool) {
        payable(address(this)).transfer(msg.value);
        L1RewardBalance += msg.value;
        emit DepositETHRewardTo(msg.sender, msg.value);
        return true;
    }

    function claimL1Reward(IStrategy[] calldata _strategies) external payable returns (bool) {
        uint256 totalShares = 0;
        uint256 userShares = 0;
        for (uint256 i = 0; i < _strategies.length; i++) {
            totalShares += _strategies[i].totalShares();
            userShares += _strategies[i].shares(msg.sender);
        }
        uint256 amountToSend = L1RewardBalance * (userShares / totalShares);
        payable(msg.sender).transfer(amountToSend);
        emit ClaimL1Reward(msg.sender, amountToSend);
        return true;
    }
}
