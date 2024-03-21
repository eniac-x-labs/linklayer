// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@/contracts/L1/interface/IDapplinkLocator.sol";

contract DapplinkLocator {
    struct Config {
        address l1Bridge;
        address dapplink;
        address depositSecurityModule;
        address stakingRouter;
        address withdrawalVault;
    }

    error ZeroAddress();

    address public immutable l1Bridge;
    address public immutable dapplink;
    address public immutable stakingRouter;
    address public immutable depositSecurityModule;
    address public immutable withdrawalVault;
    /**
     * @notice declare service locations
     * @dev accepts a struct to avoid the "stack-too-deep" error
     * @param _config struct of addresses
     */
    constructor(Config memory _config) {
        l1Bridge = _assertNonZero(_config.l1Bridge);
        dapplink = _assertNonZero(_config.dapplink);
        stakingRouter = _assertNonZero(_config.stakingRouter);
        depositSecurityModule = _assertNonZero(_config.depositSecurityModule);
        withdrawalVault = _assertNonZero(_config.withdrawalVault);
    }

    function _assertNonZero(address _address) internal pure returns (address) {
        if (_address == address(0)) revert ZeroAddress();
        return _address;
    }
}
