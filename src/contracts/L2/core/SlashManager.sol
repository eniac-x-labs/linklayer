// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {L2Base} from "@/contracts/l2/core/L2Base.sol";
import "../interfaces/ISlashManager.sol";
// import "../interfaces/IDelegationManager.sol";
// import "../interfaces/IStrategyManager.sol";


contract SlashManager is L2Base, ISlashManager {
    // IStrategyManager public immutable strategyManager;
    // ISlashManager public immutable slasher;

    constructor() {
         _disableInitializers();
    }

    function initialize(
        address initialOwner
    ) external {
        _transferOwnership(initialOwner);
    }

    function optIntoSlashing(address) external {}

    function freezeOperator(address) external {}

    function resetFrozenStatus(address[] calldata) external {}

    function recordFirstStakeUpdate(address, uint32) external {}

    function recordStakeUpdate(
        address,
        uint32,
        uint32,
        uint256
    ) external {}

    function recordLastStakeUpdateAndRevokeSlashingAbility(address, uint32) external {

    }

    function isFrozen(address) external pure returns (bool) {
         return true;
    }

    function canSlash(address, address) external pure returns (bool) {
         return true;
    }


    function contractCanSlashOperatorUntilBlock(
        address,
        address
    ) external pure returns (uint32) {
         return 0;
    }

    function latestUpdateBlock(address, address) external pure returns (uint32) {
         return 0;
    }

    function getCorrectValueForInsertAfter(address, uint32) external pure returns (uint256) {
        return 0;
    }

    function canWithdraw(
        address,
        uint32,
        uint256
    ) external pure returns (bool) {
        return true;
    }
}