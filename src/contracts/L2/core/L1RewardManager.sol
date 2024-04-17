// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;


import {L2Base} from "@/contracts/L2/core/L2Base.sol";
import "../interfaces/IStrategyManager.sol";
import "../interfaces/IL1RewardManager.sol";

contract L1RewardManager is IL1RewardManager, L2Base{
    uint256 public L1RewardBalance;

    struct AllocateObj {
        StrategyObj[] strategies;
    }
    struct StrategyObj {
        address strategy;
        OperatorObj[] operators;
    }
    struct OperatorObj {
        address strategy;
        StakerObj[] stakers;
    }
    struct StakerObj {
        address staker;
        uint256 share;
    }
    mapping(address => mapping(address => mapping (address => uint256) )) public stakerStrategyOperatorReward;

    constructor(){
        _disableInitializers();
    }

    function initialize(
        address initialOwner
    ) external initializer {
        __L2Base_init(initialOwner);
    }

    function depositETHRewardTo() external payable returns (bool) {
        payable(address(this)).transfer(msg.value);
        L1RewardBalance += msg.value;
        emit DepositETHRewardTo(msg.sender, msg.value);
        return true;
    }

    function claimL1Reward(address[] calldata _strategies) external payable returns (bool) {
        uint256 amountToSend = stakerRewardsAmount(_strategies);
        payable(msg.sender).transfer(amountToSend);
        emit ClaimL1Reward(msg.sender, amountToSend);
        return true;
    }

    // function allocateL1Reward(AllocateObj calldata _allocateObj)external onlyRelayer{
    //     uint256 totalShares = 0;
    //     for (uint256 i = 0; i < _allocateObj.strategies.length; i++) {
    //         IStrategy _strategy = getStrategy(_allocateObj.strategies[i].strategy);

    //         totalShares += _strategies[i].totalShares();
    //         // userShares += _strategies[i].shares(msg.sender);
    //     }

    //     for (uint256 i = 0; i < _allocateObj.strategies.length; i++) {
    //         IStrategy _strategy = getStrategy(_allocateObj.strategies[i]);

    //         totalShares += _strategies[i].totalShares();
    //         // userShares += _strategies[i].shares(msg.sender);
    //     }
    // }


    function stakerRewardsAmount(address[] calldata _strategies) public view returns (uint256) {
        uint256 totalShares = 0;
        uint256 userShares = 0;
        for (uint256 i = 0; i < _strategies.length; i++) {
            totalShares += getStrategy(_strategies[i]).totalShares();
            userShares += getStrategy(_strategies[i]).shares(msg.sender);
        }
        if (totalShares == 0 || userShares == 0) {
            return 0;
        }
        return L1RewardBalance * (userShares / totalShares);
    }


    // function getStrategy(address _strategy)internal view returns (IStrategy){
    //     return IStrategy(_strategy);
    // }

}
