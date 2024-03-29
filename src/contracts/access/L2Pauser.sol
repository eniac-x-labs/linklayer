// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Initializable } from "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import { AccessControlEnumerableUpgradeable } from "@openzeppelin-upgrades/contracts/access/extensions/AccessControlEnumerableUpgradeable.sol";
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

import { L2PauserStorage } from "./L2PauserStorage.sol";


contract L2Pauser is Initializable, AccessControlEnumerableUpgradeable, L2PauserStorage {
    bool public isStrategyDeposit;

    bool public isStrategyWithdraw;

    bool public isDelegate;

    bool public  isUnDelegate;

    bool public isStakerWithdraw;

    struct Init {
        address admin;
        address pauser;
        address unpauser;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(Init memory init) external initializer {
        __AccessControlEnumerable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, init.admin);
        _grantRole(PAUSER_ROLE, init.pauser);
        _grantRole(UNPAUSER_ROLE, init.unpauser);
    }

    function setIsStrategyDeposit(bool isPaused) external onlyPauserUnpauserRole(isPaused) {
        _setIsStrategyDeposit(isPaused);
    }

    function setIsStrategyWithdraw(bool isPaused) external onlyPauserUnpauserRole(isPaused) {
        _setIsStrategyWithdraw(isPaused);
    }

    function setIsDelegate(bool isPaused) external onlyPauserUnpauserRole(isPaused) {
        _setIsDelegate(isPaused);
    }

    function setIsUnDelegate(bool isPaused) external onlyPauserUnpauserRole(isPaused) {
        _setIsUnDelegate(isPaused);
    }

    function setIsStakerWithdraw(bool isPaused) external onlyPauserUnpauserRole(isPaused) {
        _setIsStakerWithdraw(isPaused);
    }

    function pauseAll() external onlyRole(PAUSER_ROLE) {
        _setIsStrategyDeposit(true);
        _setIsStrategyWithdraw(true);
        _setIsDelegate(true);
        _setIsUnDelegate(true);
        _setIsStakerWithdraw(true);
    }

    function unpauseAll() external onlyRole(UNPAUSER_ROLE) {
        _setIsStrategyDeposit(false);
        _setIsStrategyWithdraw(false);
        _setIsDelegate(false);
        _setIsUnDelegate(false);
        _setIsStakerWithdraw(false);
    }

    function _setIsStrategyDeposit(bool isPaused) internal {
        isStrategyDeposit = isPaused;
        emit FlagUpdated(this.isStrategyDeposit.selector, isPaused, "isStrategyDeposit");
    }

    function _setIsStrategyWithdraw(bool isPaused) internal {
        isStrategyWithdraw = isPaused;
        emit FlagUpdated(this.isStrategyWithdraw.selector, isPaused, "isStrategyWithdraw");
    }

    function _setIsDelegate(bool isPaused) internal {
        isDelegate = isPaused;
        emit FlagUpdated(this.isDelegate.selector, isPaused, "isDelegate");
    }

    function _setIsUnDelegate(bool isPaused) internal {
        isUnDelegate = isPaused;
        emit FlagUpdated(this.isUnDelegate.selector, isPaused, "isUnDelegate");
    }

     function _setIsStakerWithdraw(bool isPaused) internal {
        isStakerWithdraw = isPaused;
        emit FlagUpdated(this.isStakerWithdraw.selector, isPaused, "isStakerWithdraw");
    }

    modifier onlyPauserUnpauserRole(bool isPaused) {
        if (isPaused) {
            _checkRole(PAUSER_ROLE);
        } else {
            _checkRole(UNPAUSER_ROLE);
        }
        _;
    }
}
