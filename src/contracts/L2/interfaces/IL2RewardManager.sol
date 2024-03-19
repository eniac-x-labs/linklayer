// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IL2RewardManager {
    function calculateRewards() external returns (uint256);
    function depositDappLinkToken() external returns (bool);
    function operatorClaimReward() external returns (bool);
    function stakerClaimReward() external returns (bool);
}
