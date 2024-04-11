// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/ReentrancyGuardUpgradeable.sol";
import "@/contracts/L1/interfaces/L1ILocator.sol";
import { ProtocolEvents } from "../interfaces/ProtocolEvents.sol";
import {IL1Pauser} from "../../access/interface/IL1Pauser.sol";
import { IUnstakeRequestsManager } from "../interfaces/IUnstakeRequestsManager.sol";
import { IStakingManager } from "../interfaces/IStakingManager.sol";

abstract contract L1Base is Initializable, AccessControlEnumerableUpgradeable, ReentrancyGuardUpgradeable, ProtocolEvents {
    L1ILocator public locator;

    error ZeroAddress();
     /**
     * @dev
     */
    function __L1Base_init(address _admin) internal onlyInitializing {
        __AccessControlEnumerable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function setLocator(address _locator) external  {
        locator = L1ILocator(_locator);
    }
    
    function getL1Pauser()internal view returns (IL1Pauser){
        return IL1Pauser(locator.pauser());
    }

    function getUnstakeRequestsManager()internal view returns (IUnstakeRequestsManager){
        return IUnstakeRequestsManager(locator.unStakingRequestsManager());
    }

    function getStakingManager()internal view returns (IStakingManager){
        return IStakingManager(locator.stakingManager());
    }
    
    modifier notZeroAddress(address addr) {
        if (addr == address(0)) {
            revert ZeroAddress();
        }
        _;
    }
    // function getStrategyManager()external returns (IStrategyManager){
    //     return IStrategyManager(locator.strategyManager());
    // }

    // modifier onlyRelayer() {
    //     require(msg.sender == locator.relayer(), "StrategyManager.onlyRelayer");
    //     _;
    // }
}