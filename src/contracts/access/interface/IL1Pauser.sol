// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IL1Pauser {
    error PauserRoleOrOracleRequired(address sender);

    event FlagUpdated(bytes4 indexed selector, bool indexed isPaused, string flagName);

    function pauseAll() external;

    function isStakingPaused() external view returns (bool);

    function isUnstakeRequestsAndClaimsPaused() external view returns (bool);

    function isInitiateValidatorsPaused() external view returns (bool);

    function isSubmitOracleRecordsPaused() external view returns (bool);

    function isAllocateETHPaused() external view returns (bool);
}
