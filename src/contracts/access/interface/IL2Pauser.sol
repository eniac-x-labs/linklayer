// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IL2Pauser {
    error PauserRoleOrOracleRequired(address sender);

    event FlagUpdated(bytes4 indexed selector, bool indexed isPaused, string flagName);

    function pauseAll() external;

    function isStrategyDeposit() external view returns (bool);

    function isStrategyWithdraw() external view returns (bool);

    function isDelegate() external view returns (bool);

    function isUnDelegate() external view returns (bool);

    function isStakerWithdraw() external view returns (bool);
}
