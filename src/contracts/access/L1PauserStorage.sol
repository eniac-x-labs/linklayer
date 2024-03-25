// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interface/IL1Pauser.sol";

abstract contract L1PauserStorage is IL1Pauser {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");
}
