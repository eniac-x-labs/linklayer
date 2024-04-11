// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface L2ILocator {
    function delegation() external view returns(address);
    function strategyManager() external view returns(address);
    function rewardToken() external view returns(address);
    function pauser() external view returns(address);
    function slasher() external view returns(address);
    function relayer() external view returns(address);
    
    function coreComponents() external view returns(
        address delegation,
        address strategyManager,
        address rewardToken,
        address pauser,
        address slasher,
        address relayer
    );
}