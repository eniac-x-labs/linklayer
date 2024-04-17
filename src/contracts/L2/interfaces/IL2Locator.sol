// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface IL2Locator {
    function delegation() external view returns(address);
    function strategyManager() external view returns(address);
    function dapplinkToken() external view returns(address);
    function pauser() external view returns(address);
    function slasher() external view returns(address);
    function relayer() external view returns(address);
    function l1RewardManager() external view returns(address);
    function l2RewardManager() external view returns(address);
    
    function coreComponents() external view returns(
        address delegation,
        address strategyManager,
        address dapplinkToken,
        address pauser,
        address slasher,
        address relayer,
        address l1RewardManager,
        address l2RewardManager
    );
}