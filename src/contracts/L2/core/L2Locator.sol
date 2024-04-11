// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@/contracts/L2/interfaces/L2ILocator.sol";

contract L2Locator {
    struct Config {
        address delegation;
        address strategyManager;
        address rewardToken;
        address pauser;
        address slasher;
        address relayer;
    }

    error ZeroAddress();

    address public immutable delegation;
    address public immutable strategyManager;
    address public immutable rewardToken;
    address public immutable pauser;
    address public immutable slasher;
    address public immutable relayer;

    /**
     * @notice declare service locations
     * @dev accepts a struct to avoid the "stack-too-deep" error
     * @param _config struct of addresses
     */
    constructor(Config memory _config) {
        delegation = _assertNonZero(_config.delegation);
        strategyManager = _assertNonZero(_config.strategyManager);
        rewardToken = _assertNonZero(_config.rewardToken);
        pauser = _assertNonZero(_config.pauser);
        slasher = _assertNonZero(_config.slasher);
        relayer = _assertNonZero(_config.relayer);
    }

    function _assertNonZero(address _address) internal pure returns (address) {
        if (_address == address(0)) revert ZeroAddress();
        return _address;
    }
}
