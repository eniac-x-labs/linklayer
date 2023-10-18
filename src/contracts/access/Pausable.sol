// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "./interface/IPausable.sol";

contract Pausable is IPausable {
    IPauserRegistry public pauserRegistry;

    uint256 private _paused;

    uint256 internal constant UNPAUSE_ALL = 0;
    uint256 internal constant PAUSE_ALL = type(uint256).max;

    modifier onlyPauser() {
        require(pauserRegistry.isPauser(msg.sender), "msg.sender is not permissioned as pauser");
        _;
    }

    modifier onlyUnpauser() {
        require(msg.sender == pauserRegistry.unpauser(), "msg.sender is not permissioned as unpauser");
        _;
    }

    modifier whenNotPaused() {
        require(_paused == 0, "Pausable: contract is paused");
        _;
    }

    modifier onlyWhenNotPaused(uint8 index) {
        require(!paused(index), "Pausable: index is paused");
        _;
    }

    function _initializePauser(IPauserRegistry _pauserRegistry, uint256 initPausedStatus) internal {
        require(
            address(pauserRegistry) == address(0) && address(_pauserRegistry) != address(0),
            "Pausable._initializePauser: _initializePauser() can only be called once"
        );
        _paused = initPausedStatus;
        emit Paused(msg.sender, initPausedStatus);
        _setPauserRegistry(_pauserRegistry);
    }

    function pause(uint256 newPausedStatus) external onlyPauser {
        require((_paused & newPausedStatus) == _paused, "Pausable.pause: invalid attempt to unpause functionality");
        _paused = newPausedStatus;
        emit Paused(msg.sender, newPausedStatus);
    }

    function pauseAll() external onlyPauser {
        _paused = type(uint256).max;
        emit Paused(msg.sender, type(uint256).max);
    }

    function unpause(uint256 newPausedStatus) external onlyUnpauser {
        require(
            ((~_paused) & (~newPausedStatus)) == (~_paused),
            "Pausable.unpause: invalid attempt to pause functionality"
        );
        _paused = newPausedStatus;
        emit Unpaused(msg.sender, newPausedStatus);
    }

    function paused() public view virtual returns (uint256) {
        return _paused;
    }

    function paused(uint8 index) public view virtual returns (bool) {
        uint256 mask = 1 << index;
        return ((_paused & mask) == mask);
    }

    function setPauserRegistry(IPauserRegistry newPauserRegistry) external onlyUnpauser {
        _setPauserRegistry(newPauserRegistry);
    }

    function _setPauserRegistry(IPauserRegistry newPauserRegistry) internal {
        require(
            address(newPauserRegistry) != address(0),
            "Pausable._setPauserRegistry: newPauserRegistry cannot be the zero address"
        );
        emit PauserRegistrySet(pauserRegistry, newPauserRegistry);
        pauserRegistry = newPauserRegistry;
    }

    uint256[48] private __gap;
}