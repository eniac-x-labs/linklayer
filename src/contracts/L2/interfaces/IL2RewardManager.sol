// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/IStrategy.sol";

interface IL2RewardManager {
     event DepositDappLinkToken(
         address sender,
         uint256 amount
     );

    event OperatorStakerReward(
        IStrategy strategy,
        address operator,
        uint256 stakerFee,
        uint256 operatorFee
    );

    event OperatorClaimReward (
        address operator,
        uint256 amount
    );

    event StakerClaimReward(
        address staker,
        uint256 amount
    );

    function calculateFee(IStrategy strategy, address operator, uint256 baseFee) external;
    function depositDappLinkToken(uint256 amount) external returns (bool);
    function operatorClaimReward() external returns (bool);
    function stakerClaimReward(IStrategy strategy) external returns (bool);
    function updateOperatorAndStakerShareFee(uint256 _stakerPercent) external;
}
