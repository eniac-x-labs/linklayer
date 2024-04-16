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
import { IDETH } from "../interfaces/IDETH.sol";
import { IDepositContract } from "../interfaces/IDepositContract.sol";

abstract contract L1Base is Initializable, AccessControlEnumerableUpgradeable, ReentrancyGuardUpgradeable, ProtocolEvents {
    address public locator;

    error ZeroAddress();
     /**
     * @dev
     */
    function __L1Base_init(address _admin) internal onlyInitializing {
        __AccessControlEnumerable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function setLocator(address _locator) external onlyRole(DEFAULT_ADMIN_ROLE){
        locator = _locator;
    }

    function getLocator() public view returns (L1ILocator) {
        return L1ILocator(locator);
    }
    
    function getL1Pauser()internal view returns (IL1Pauser){
        return IL1Pauser(getLocator().pauser());
    }

    function getUnstakeRequestsManager()internal view returns (IUnstakeRequestsManager){
        return IUnstakeRequestsManager(getLocator().unStakingRequestsManager());
    }

    function getStakingManager()internal view returns (IStakingManager){
        return IStakingManager(getLocator().stakingManager());
    }
    function getDETH()internal view returns (IDETH){
        return IDETH(getLocator().dETH());
    }

    function getDepositContract()internal view returns (IDepositContract){
        return IDepositContract(getLocator().depositContract());
    }

    modifier notZeroAddress(address addr) {
        if (addr == address(0)) {
            revert ZeroAddress();
        }
        _;
    }
    // function getStrategyManager()external returns (IStrategyManager){
    //     return IStrategyManager(getLocator().strategyManager());
    // }

    modifier onlyRelayer() {
        require(msg.sender == getLocator().relayerAddress(), "Not Relayer" );
        _;
    }
}