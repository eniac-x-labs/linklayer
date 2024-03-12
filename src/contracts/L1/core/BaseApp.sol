// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@/contracts/L1/interface/IDapplinkLocator.sol";
import "@openzeppelin-upgrades/contracts/access/AccessControlUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
abstract contract BaseApp is Initializable, AccessControlUpgradeable {

    IDapplinkLocator locator;
    
    /**
     * @dev
     */
    function __BaseApp_init(address _locator) internal onlyInitializing {
        locator = IDapplinkLocator(_locator);
    }
    
    function _onlyNonZeroAddress(address _a) internal pure {
        require(_a != address(0), "ZERO_ADDRESS");
    }

}