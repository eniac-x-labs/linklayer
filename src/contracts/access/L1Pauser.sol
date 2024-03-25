// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import { AccessControlEnumerableUpgradeable } from "@openzeppelin-upgrades/contracts/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

import { IOracleManager } from "../L1/interfaces/IOracleManager.sol";
import {L1PauserStorage} from "./L1PauserStorage.sol";


contract L1Pauser is Initializable, AccessControlEnumerableUpgradeable, L1PauserStorage {
    bool public isStakingPaused;

    bool public isUnstakeRequestsAndClaimsPaused;

    bool public isInitiateValidatorsPaused;

    bool public isSubmitOracleRecordsPaused;

    bool public isAllocateETHPaused;

    bool public isStrategyDeposit;

    bool public isStrategyWithdraw;

    IOracleManager public oracle;

    struct Init {
        address admin;
        address pauser;
        address unpauser;
        IOracleManager oracle;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(Init memory init) external initializer {
        __AccessControlEnumerable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, init.admin);
        _grantRole(PAUSER_ROLE, init.pauser);
        _grantRole(UNPAUSER_ROLE, init.unpauser);
        oracle = init.oracle;
    }

    function setIsStakingPaused(bool isPaused) external onlyPauserUnpauserRole(isPaused) {
        _setIsStakingPaused(isPaused);
    }

    function setIsUnstakeRequestsAndClaimsPaused(bool isPaused) external onlyPauserUnpauserRole(isPaused) {
        _setIsUnstakeRequestsAndClaimsPaused(isPaused);
    }

    function setIsInitiateValidatorsPaused(bool isPaused) external onlyPauserUnpauserRole(isPaused) {
        _setIsInitiateValidatorsPaused(isPaused);
    }

    function setIsSubmitOracleRecordsPaused(bool isPaused) external onlyPauserUnpauserRole(isPaused) {
        _setIsSubmitOracleRecordsPaused(isPaused);
    }

    function setIsAllocateETHPaused(bool isPaused) external onlyPauserUnpauserRole(isPaused) {
        _setIsAllocateETHPaused(isPaused);
    }

    function pauseAll() external {
        _verifyPauserOrOracle();

        _setIsStakingPaused(true);
        _setIsUnstakeRequestsAndClaimsPaused(true);
        _setIsInitiateValidatorsPaused(true);
        _setIsSubmitOracleRecordsPaused(true);
        _setIsAllocateETHPaused(true);
    }

    function unpauseAll() external onlyRole(UNPAUSER_ROLE) {
        _setIsStakingPaused(false);
        _setIsUnstakeRequestsAndClaimsPaused(false);
        _setIsInitiateValidatorsPaused(false);
        _setIsSubmitOracleRecordsPaused(false);
        _setIsAllocateETHPaused(false);
    }

    function _verifyPauserOrOracle() internal view {
        if (hasRole(PAUSER_ROLE, msg.sender) || msg.sender == address(oracle)) {
            return;
        }
        revert PauserRoleOrOracleRequired(msg.sender);
    }

    function _setIsStakingPaused(bool isPaused) internal {
        isStakingPaused = isPaused;
        emit FlagUpdated(this.isStakingPaused.selector, isPaused, "isStakingPaused");
    }

    function _setIsUnstakeRequestsAndClaimsPaused(bool isPaused) internal {
        isUnstakeRequestsAndClaimsPaused = isPaused;
        emit FlagUpdated(this.isUnstakeRequestsAndClaimsPaused.selector, isPaused, "isUnstakeRequestsAndClaimsPaused");
    }

    function _setIsInitiateValidatorsPaused(bool isPaused) internal {
        isInitiateValidatorsPaused = isPaused;
        emit FlagUpdated(this.isInitiateValidatorsPaused.selector, isPaused, "isInitiateValidatorsPaused");
    }

    function _setIsSubmitOracleRecordsPaused(bool isPaused) internal {
        isSubmitOracleRecordsPaused = isPaused;
        emit FlagUpdated(this.isSubmitOracleRecordsPaused.selector, isPaused, "isSubmitOracleRecordsPaused");
    }

    function _setIsAllocateETHPaused(bool isPaused) internal {
        isAllocateETHPaused = isPaused;
        emit FlagUpdated(this.isAllocateETHPaused.selector, isPaused, "isAllocateETHPaused");
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
