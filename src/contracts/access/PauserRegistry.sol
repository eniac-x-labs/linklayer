// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "../interface/IPauserRegistry.sol";


contract PauserRegistry is IPauserRegistry {
    mapping(address => bool) public isPauser;

    address public unpauser;

    modifier onlyUnpauser() {
        require(msg.sender == unpauser, "msg.sender is not permissioned as unpauser");
        _;
    }

    constructor(address[] memory _pausers, address _unpauser) {
        for (uint256 i = 0; i < _pausers.length; i++) {
            _setIsPauser(_pausers[i], true);
        }
        _setUnpauser(_unpauser);
    }

    function setIsPauser(address newPauser, bool canPause) external onlyUnpauser {
        _setIsPauser(newPauser, canPause);
    }

    function setUnpauser(address newUnpauser) external onlyUnpauser {
        _setUnpauser(newUnpauser);
    }

    function _setIsPauser(address pauser, bool canPause) internal {
        require(pauser != address(0), "PauserRegistry._setPauser: zero address input");
        isPauser[pauser] = canPause;
        emit PauserStatusChanged(pauser, canPause);
    }

    function _setUnpauser(address newUnpauser) internal {
        require(newUnpauser != address(0), "PauserRegistry._setUnpauser: zero address input");
        emit UnpauserChanged(unpauser, newUnpauser);
        unpauser = newUnpauser;
    }
}