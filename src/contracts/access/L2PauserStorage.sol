// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interface/IL2Pauser.sol";


abstract contract L2PauserStorage is IL2Pauser {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");
}
