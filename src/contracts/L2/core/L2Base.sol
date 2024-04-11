// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/ReentrancyGuardUpgradeable.sol";
import "@/contracts/L2/interfaces/L2ILocator.sol";
import "@/contracts/L2/interfaces/IStrategyManager.sol";
abstract contract L2Base is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    L2ILocator locator;
     /**
     * @dev
     */
    function __L2Base_init(address _admin) internal onlyInitializing {
        // _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _transferOwnership(_admin);
    }

    function setLocator(address _locator) external onlyRelayer {
        locator = L2ILocator(_locator);
    }
    

    function getStrategyManager()external returns (IStrategyManager){
        return IStrategyManager(locator.strategyManager());
    }

    modifier onlyRelayer() {
        require(msg.sender == locator.relayer(), "StrategyManager.onlyRelayer");
        _;
    }
}