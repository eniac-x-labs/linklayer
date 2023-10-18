// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "../interface/IPauserRegistry.sol";


interface IPausable {
    event PauserRegistrySet(IPauserRegistry pauserRegistry, IPauserRegistry newPauserRegistry);

    event Paused(address indexed account, uint256 newPausedStatus);

    event Unpaused(address indexed account, uint256 newPausedStatus);

    function pauserRegistry() external view returns (IPauserRegistry);

    function pause(uint256 newPausedStatus) external;

    function pauseAll() external;

    function unpause(uint256 newPausedStatus) external;

    function paused() external view returns (uint256);

    function paused(uint8 index) external view returns (bool);

    function setPauserRegistry(IPauserRegistry newPauserRegistry) external;
}