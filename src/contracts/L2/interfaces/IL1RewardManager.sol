// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "../interfaces/IStrategyManager.sol";
import "../interfaces/IStrategy.sol";


interface IL1RewardManager {
     event DepositETHRewardTo(
         address sender,
         uint256 amount
     );

    event ClaimL1Reward(
         address receiver,
         uint256 amount
     );

    function depositETHRewardTo() external payable returns (bool);
    function claimL1Reward() external payable returns (bool);
}
