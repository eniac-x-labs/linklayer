// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OracleRecord} from "./IOracleManager.sol";

interface IReturnsAggregator {
    error InvalidConfiguration();
    error NotOracle();
    error Paused();
    error ZeroAddress();

    event FeesCollected(uint256 amount);

    function processReturns(uint256 rewardAmount, uint256 principalAmount, bool shouldIncludeELRewards) external;
}
