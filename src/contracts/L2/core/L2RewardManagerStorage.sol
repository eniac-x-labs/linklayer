// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/IL2RewardManager.sol";
import "../interfaces/IStrategy.sol";


abstract contract L2RewardManagerStorage is IL2RewardManager {
       mapping(IStrategy => uint256) public stakerRewards;
       mapping(address => uint256) public operatorRewards;
}
