// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;


interface IPauserRegistry {
    event PauserStatusChanged(address pauser, bool canPause);

    event UnpauserChanged(address previousUnpauser, address newUnpauser);
    
    function isPauser(address pauser) external view returns (bool);

    function unpauser() external view returns (address);
}