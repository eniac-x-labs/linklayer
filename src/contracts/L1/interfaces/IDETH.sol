// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin-upgrades/contracts/token/ERC20/ERC20Upgradeable.sol";
import { IERC20Permit } from "@openzeppelin-upgrades/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";


interface IDETH is IERC20, IERC20Permit {
    error NotStakingManagerContract();
    error NotUnstakeRequestsManagerContract();

    function mint(address staker, uint256 amount) external;
    function burn(uint256 amount) external;
}