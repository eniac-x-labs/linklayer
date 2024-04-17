// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

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
    function claimL1Reward(address[] calldata _strategies) external payable returns (bool);
}
