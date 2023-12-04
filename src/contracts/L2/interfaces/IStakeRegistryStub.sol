// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "./IStakeRegistryStub.sol";

interface IStakeRegistryStub {
    function updateStakes(address[] memory operators) external;
}
