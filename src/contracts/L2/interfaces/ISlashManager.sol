// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./IStrategyManager.sol";
import "./IDelegationManager.sol";


interface ISlashManager {

    event OptedIntoSlashing(address indexed operator, address indexed contractAddress);

    event SlashingAbilityRevoked(
        address indexed operator,
        address indexed contractAddress,
        uint32 contractCanSlashOperatorUntilBlock
    );

    event OperatorFrozen(address indexed slashedOperator, address indexed slashingContract);

    event FrozenStatusReset(address indexed previouslySlashedAddress);

    function optIntoSlashing(address contractAddress) external;

    function freezeOperator(address toBeFrozen) external;

    function resetFrozenStatus(address[] calldata frozenAddresses) external;

    function recordFirstStakeUpdate(address operator, uint32 serveUntilBlock) external;

    function recordStakeUpdate(
        address operator,
        uint32 updateBlock,
        uint32 serveUntilBlock,
        uint256 insertAfter
    ) external;

    function recordLastStakeUpdateAndRevokeSlashingAbility(address operator, uint32 serveUntilBlock) external;

    function isFrozen(address staker) external view returns (bool);

    function canSlash(address toBeSlashed, address slashingContract) external view returns (bool);

    function contractCanSlashOperatorUntilBlock(
        address operator,
        address serviceContract
    ) external view returns (uint32);

    function latestUpdateBlock(address operator, address serviceContract) external view returns (uint32);

    function getCorrectValueForInsertAfter(address operator, uint32 updateBlock) external view returns (uint256);

    function canWithdraw(
        address operator,
        uint32 withdrawalStartBlock,
        uint256 middlewareTimesIndex
    ) external returns (bool);
}
