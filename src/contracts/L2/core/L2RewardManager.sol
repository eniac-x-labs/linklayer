// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IStrategyManager.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IL2RewardManager.sol";

contract L2RewardManager is IL2RewardManager, Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    constructor(){
    }

    function initialize(
        address initialOwner
    ) external initializer {
        _transferOwnership(initialOwner);
    }

    function calculateRewards() external returns (uint256) {
        return 0;
    }

    function depositDappLinkToken() external returns (bool){
         return true;
    }

    function operatorClaimReward() external returns (bool){
         return true;
    }

    function stakerClaimReward() external returns (bool){
         return true;
    }
}
