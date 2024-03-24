// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";

import "../interfaces/ISlashManager.sol";
import "../interfaces/IDelegationManager.sol";
import "../interfaces/IStrategyManager.sol";
import "../../access/Pausable.sol";



contract SlashManager is Initializable, OwnableUpgradeable, ISlashManager, Pausable {
    IStrategyManager public immutable strategyManager;
    ISlashManager public immutable slasher;

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