// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface L1ILocator {
    function stakingManager() external view returns(address);
    function unStakingRequestsManager() external view returns(address);
    function dETH() external view returns(address);
    function pauser() external view returns(address);
    function returnsAggregator() external view returns(address);
    function oracleManager() external view returns(address);
    function oracleQuorumManager() external view returns(address);
    function consensusLayerReceiver() external view returns(address);
    function executionLayerReceiver() external view returns(address);
    function dapplinkBridge() external view returns(address);
    function depositContract() external view returns(address);
    function relayerAddress() external view returns(address);
    
    
    function coreComponents() external view returns(
        address stakingManager,
        address unStakingRequestsManager,
        address dETH,
        address pauser,
        address returnsAggregator,
        address oracleManager,
        address oracleQuorumManager,
        address consensusLayerReceiver,
        address executionLayerReceiver,
        address dapplinkBridge,
        address depositContract,
        address relayerAddress
    );
}