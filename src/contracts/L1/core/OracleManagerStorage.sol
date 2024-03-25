// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {
    IOracleManager,
    IOracleReadRecord,
    IOracleReadPending,
    IOracleWrite,
    OracleRecord
} from "../interfaces/IOracleManager.sol";

abstract contract OracleManagerStorage is IOracleManager {
    bytes32 public constant ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE");

    bytes32 public constant ORACLE_MODIFIER_ROLE = keccak256("ORACLE_MODIFIER_ROLE");

    bytes32 public constant ORACLE_PENDING_UPDATE_RESOLVER_ROLE = keccak256("ORACLE_PENDING_UPDATE_RESOLVER_ROLE");

    uint256 internal constant _FINALIZATION_BLOCK_NUMBER_DELTA_UPPER_BOUND = 2048;

    OracleRecord[] internal _records;

    uint256[50] private __gap;
}
