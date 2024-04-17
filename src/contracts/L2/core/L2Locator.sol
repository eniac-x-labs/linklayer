// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@/contracts/L2/interfaces/IL2Locator.sol";

contract L2Locator {
    struct Config {
        address delegation;
        address strategyManager;
        address dapplinkToken;
        address pauser;
        address slasher;
        address relayer;
        address l1RewardManager;
        address l2RewardManager;
    }

    error ZeroAddress();

    address public immutable delegation;
    address public immutable strategyManager;
    address public immutable dapplinkToken;
    address public immutable pauser;
    address public immutable slasher;
    address public immutable relayer;
    address public immutable l1RewardManager;
    address public immutable l2RewardManager;

    /**
     * @notice declare service locations
     * @dev accepts a struct to avoid the "stack-too-deep" error
     * @param _config struct of addresses
     */
    constructor(Config memory _config) {
        delegation = _assertNonZero(_config.delegation);
        strategyManager = _assertNonZero(_config.strategyManager);
        dapplinkToken = _assertNonZero(_config.dapplinkToken);
        pauser = _assertNonZero(_config.pauser);
        slasher = _assertNonZero(_config.slasher);
        relayer = _assertNonZero(_config.relayer);
        l1RewardManager = _assertNonZero(_config.l1RewardManager);
        l2RewardManager = _assertNonZero(_config.l2RewardManager);
    }

    function _assertNonZero(address _address) internal pure returns (address) {
        if (_address == address(0)) revert ZeroAddress();
        return _address;
    }
}
