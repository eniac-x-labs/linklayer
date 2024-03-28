// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import { IStakingManager, IStakingManagerReturnsWrite, IStakingManagerInitiationRead } from "../interfaces/IStakingManager.sol";

abstract contract StakingManagerStorage is IStakingManager {
    bytes32 public constant STAKING_MANAGER_ROLE = keccak256("STAKING_MANAGER_ROLE");

    bytes32 public constant ALLOCATOR_SERVICE_ROLE = keccak256("ALLOCATER_SERVICE_ROLE");

    bytes32 public constant INITIATOR_SERVICE_ROLE = keccak256("INITIATOR_SERVICE_ROLE");

    bytes32 public constant STAKING_ALLOWLIST_MANAGER_ROLE = keccak256("STAKING_ALLOWLIST_MANAGER_ROLE");

    bytes32 public constant STAKING_ALLOWLIST_ROLE = keccak256("STAKING_ALLOWLIST_ROLE");

    bytes32 public constant TOP_UP_ROLE = keccak256("TOP_UP_ROLE");

    struct ValidatorParams {
        uint256 operatorID;
        uint256 depositAmount;
        bytes pubkey;
        bytes withdrawalCredentials;
        bytes signature;
        bytes32 depositDataRoot;
    }

    uint256[50] private __gap;
}
