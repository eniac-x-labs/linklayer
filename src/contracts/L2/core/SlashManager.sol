// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";

import "../interfaces/ISlashManager.sol";
import "../interfaces/IDelegationManager.sol";
import "../interfaces/IStrategyManager.sol";
import "../../access/Pausable.sol";



contract SlashManager is Initializable, OwnableUpgradeable, ISlashManager, Pausable {

    constructor(IStrategyManager, IDelegationManager) {}

    function initialize(
        address,
        IPauserRegistry,
        uint256
    ) external {}

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

    function recordLastStakeUpdateAndRevokeSlashingAbility(address, uint32) external {}

    function strategyManager() external view returns (IStrategyManager) {}

    function delegation() external view returns (IDelegationManager) {}

    function isFrozen(address) external view returns (bool) {}

    function canSlash(address, address) external view returns (bool) {}

    function contractCanSlashOperatorUntilBlock(
        address,
        address
    ) external view returns (uint32) {}

    function latestUpdateBlock(address, address) external view returns (uint32) {}

    function getCorrectValueForInsertAfter(address, uint32) external view returns (uint256) {}

    function canWithdraw(
        address,
        uint32,
        uint256
    ) external returns (bool) {}

    function operatorToMiddlewareTimes(
        address,
        uint256
    ) external view returns (MiddlewareTimes memory) {}

    function middlewareTimesLength(address) external view returns (uint256) {}

    function getMiddlewareTimesIndexStalestUpdateBlock(address, uint32) external view returns (uint32) {}

    function getMiddlewareTimesIndexServeUntilBlock(address, uint32) external view returns (uint32) {}

    function operatorWhitelistedContractsLinkedListSize(address) external view returns (uint256) {}

    function operatorWhitelistedContractsLinkedListEntry(
        address,
        address
    ) external view returns (bool, uint256, uint256) {}

    function whitelistedContractDetails(
        address,
        address
    ) external view returns (MiddlewareDetails memory) {}

}