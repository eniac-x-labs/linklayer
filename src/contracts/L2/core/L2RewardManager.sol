// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IStrategyManager.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IL2RewardManager.sol";

import "./L2RewardManagerStorage.sol";


contract L2RewardManager is IL2RewardManager, Initializable, OwnableUpgradeable, L2RewardManagerStorage, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    IERC20 public rewardToken;

    IDelegationManager public delegation;

    IStrategyManager public strategyManager;

    uint256 public stakerPercent = 92;

    constructor(){
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        IDelegationManager _delegation,
        IStrategyManager _strategyManager,
        IERC20 _rewardToken
    ) external initializer {
        _transferOwnership(initialOwner);
        delegation = _delegation;
        strategyManager = _strategyManager;
        rewardToken = _rewardToken;
    }

    function calculateFee(IStrategy strategy, address operator, uint256 baseFee) external {
        uint256 totalShares = strategy.totalShares();
        uint256 operatorShares = delegation.operatorShares(operator, strategy);
        uint256 operatorTotalFee = baseFee / (operatorShares / totalShares);

        uint256 stakerFee = operatorTotalFee * (stakerPercent / 100);
        stakerRewards[strategy] = stakerFee;

        uint256 operatorFee = operatorTotalFee * ((100 - stakerPercent) / 100);
        operatorRewards[operator] = operatorFee;

        emit OperatorStakerReward(
            strategy,
            operator,
            stakerFee,
            operatorFee
        );
    }

    function depositDappLinkToken(uint256 amount) external returns (bool){
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        emit DepositDappLinkToken(msg.sender, amount);
        return true;
    }

    function operatorClaimReward() external returns (bool){
        uint256 claimAmount = operatorRewards[msg.sender];
        rewardToken.safeTransferFrom(address(this), msg.sender, claimAmount);
        emit OperatorClaimReward(
            msg.sender,
            claimAmount
        );
        return true;
    }

    function stakerClaimReward(IStrategy strategy) external returns (bool){
        uint256 stakerShare = strategyManager.stakerStrategyShares(msg.sender, strategy);
        uint256 strategyShares = strategy.totalShares();
        uint256 stakerAmount = stakerRewards[strategy] * (stakerShare /  strategyShares);

        rewardToken.safeTransferFrom(address(this), msg.sender, stakerAmount);
        emit StakerClaimReward(
            msg.sender,
            stakerAmount
        );
        return true;
    }

    function updateOperatorAndStakerShareFee(uint256 _stakerPercent) external {
         stakerPercent = _stakerPercent;
    }
}
