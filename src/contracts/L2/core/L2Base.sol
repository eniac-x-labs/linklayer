// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/ReentrancyGuardUpgradeable.sol";

import {IL2Pauser} from "@/contracts/access/interface/IL2Pauser.sol";
import {IL2Locator} from "@/contracts/L2/interfaces/IL2Locator.sol";
import {IStrategyManager} from "@/contracts/L2/interfaces/IStrategyManager.sol";
import {ISlashManager} from "@/contracts/L2/interfaces/ISlashManager.sol";
import {IDelegationManager} from "@/contracts/L2/interfaces/IDelegationManager.sol";
import {IStrategy} from "@/contracts/l2/interfaces/IStrategy.sol";

abstract contract L2Base is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    address locator;
     /**
     * @dev
     */
    function __L2Base_init(address _admin) internal onlyInitializing {
        // _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _transferOwnership(_admin);
    }

    function setLocator(address _locator) external {
        locator = _locator;
    }

    function getLocator() public view returns(IL2Locator) {
        return IL2Locator(locator);
    }

    function getDapplinkToken()public view returns (IERC20){
        return IERC20(getLocator().dapplinkToken());
    }

    function getSlashManager()public view returns (ISlashManager){
        return ISlashManager(getLocator().slasher());
    }

    function getL2Pauser()public view returns (IL2Pauser){
        return IL2Pauser(getLocator().pauser());
    }

    function getStrategyManager()public view returns (IStrategyManager){
        return IStrategyManager(getLocator().strategyManager());
    }

    function getDelegationManager()public view returns (IDelegationManager){
        return IDelegationManager(getLocator().delegation());
    }
    
    function getStrategy(address _strategy)public pure returns (IStrategy){
        return IStrategy(_strategy);
    }

    modifier onlyRelayer() {
        require(msg.sender == getLocator().relayer(), "onlyRelayer");
        _;
    }

    modifier onlyStrategyManager() {
        require(
            msg.sender == getLocator().strategyManager(),
            "onlyStrategyManager"
        );
        _;
    }
    modifier onlyDelegationManager() {
        require(msg.sender == getLocator().delegation(), "onlyDelegationManager");
        _;
    }
}