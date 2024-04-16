// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@/contracts/L1/interfaces/L1ILocator.sol";

contract L1Locator {
    struct Config {
        address stakingManager;
        address unStakingRequestsManager;
        address dETH;
        address pauser;
        address returnsAggregator;
        address oracleManager;
        address oracleQuorumManager;
        address consensusLayerReceiver;
        address executionLayerReceiver;
        address dapplinkBridge;
        address depositContract;
        address relayerAddress;
    }

    error ZeroAddress();

    address public stakingManager;
    address public unStakingRequestsManager;
    address public dETH;
    address public pauser;
    address public returnsAggregator;
    address public oracleManager;
    address public oracleQuorumManager;
    address public consensusLayerReceiver;
    address public executionLayerReceiver;
    address public dapplinkBridge;
    address public depositContract;
    address public relayerAddress;
    

    /**
     * @notice declare service locations
     * @dev accepts a struct to avoid the "stack-too-deep" error
     * @param _config struct of addresses
     */
    constructor(Config memory _config) {
        stakingManager = _assertNonZero(_config.stakingManager);
        unStakingRequestsManager = _assertNonZero(_config.unStakingRequestsManager);
        dETH = _assertNonZero(_config.dETH);
        pauser = _assertNonZero(_config.pauser);
        returnsAggregator = _assertNonZero(_config.returnsAggregator);
        oracleManager = _assertNonZero(_config.oracleManager);
        oracleQuorumManager = _assertNonZero(_config.oracleQuorumManager);
        consensusLayerReceiver = _assertNonZero(_config.consensusLayerReceiver);
        executionLayerReceiver = _assertNonZero(_config.executionLayerReceiver);
        dapplinkBridge = _assertNonZero(_config.dapplinkBridge);
        depositContract = _assertNonZero(_config.depositContract);
        relayerAddress = _assertNonZero(_config.relayerAddress);
    }

    function _assertNonZero(address _address) internal pure returns (address) {
        if (_address == address(0)) revert ZeroAddress();
        return _address;
    }

    function setStakingManager(address _stakingManager) external {
        stakingManager = _stakingManager;
    }
}
