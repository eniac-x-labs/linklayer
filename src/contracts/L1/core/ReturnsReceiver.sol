// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {L1Base} from "@/contracts/L1/core/L1Base.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";


contract ReturnsReceiver is L1Base {
    bytes32 public constant RECEIVER_MANAGER_ROLE = keccak256("RECEIVER_MANAGER_ROLE");

    bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");

    struct Init {
        address admin;
        address manager;
        address withdrawer;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(Init memory init) external initializer {
        __L1Base_init(init.admin);
        _grantRole(RECEIVER_MANAGER_ROLE, init.manager);
        _setRoleAdmin(WITHDRAWER_ROLE, RECEIVER_MANAGER_ROLE);
        _grantRole(WITHDRAWER_ROLE, init.withdrawer);
    }

    function transfer(address payable to, uint256 amount) external onlyRole(WITHDRAWER_ROLE) {
        Address.sendValue(to, amount);
    }

    function transferERC20(IERC20 token, address to, uint256 amount) external onlyRole(WITHDRAWER_ROLE) {
        SafeERC20.safeTransfer(token, to, amount);
    }

    receive() external payable {}
}
