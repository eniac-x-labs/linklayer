// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ProtocolEvents {
    event ProtocolConfigChanged(bytes4 indexed setterSelector, string setterSignature, bytes value);
}
