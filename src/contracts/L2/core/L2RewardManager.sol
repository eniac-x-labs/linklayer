// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;


import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {L2RewardManagerStorage} from "@/contracts/l2/core/L2RewardManagerStorage.sol";
import {L2Base} from "@/contracts/l2/core/L2Base.sol";

contract L2RewardManager is L2Base, L2RewardManagerStorage {
    using SafeERC20 for IERC20;
    uint256 public stakerPercent = 92;

    constructor(){
        _disableInitializers();
    }

    function initialize(
        address initialOwner
    ) external initializer {
        __L2Base_init(initialOwner);
    }

    function calculateFee(address strategy, address operator, uint256 baseFee) external {
        uint256 totalShares = getStrategy(strategy).totalShares();
        uint256 operatorShares = getDelegationManager().operatorShares(operator, strategy);
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
        getDapplinkToken().safeTransferFrom(msg.sender, address(this), amount);
        emit DepositDappLinkToken(msg.sender, amount);
        return true;
    }

    function operatorClaimReward() external returns (bool){
        uint256 claimAmount = operatorRewards[msg.sender];
        getDapplinkToken().safeTransferFrom(address(this), msg.sender, claimAmount);
        emit OperatorClaimReward(
            msg.sender,
            claimAmount
        );
        return true;
    }

    function stakerClaimReward(address strategy) external returns (bool){
       uint256 stakerAmount = stakerRewardsAmount(strategy);
        getDapplinkToken().safeTransferFrom(address(this), msg.sender, stakerAmount);
        emit StakerClaimReward(
            msg.sender,
            stakerAmount
        );
        return true;
    }

    function stakerRewardsAmount(address strategy) public view returns (uint256){
        uint256 stakerShare = getStrategyManager().getStakerStrategyShares(msg.sender, strategy);
        uint256 strategyShares = getStrategy(strategy).totalShares();
        if (stakerShare == 0 ||strategyShares == 0) {
            return 0;
        }
        return stakerRewards[strategy] * (stakerShare /  strategyShares);
    }

    function updateOperatorAndStakerShareFee(uint256 _stakerPercent) external {
         stakerPercent = _stakerPercent;
    }
}
