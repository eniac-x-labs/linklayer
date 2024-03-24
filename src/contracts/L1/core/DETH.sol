// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Initializable } from "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import { ERC20PermitUpgradeable, IERC20Permit } from "@openzeppelin-upgrades/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { AccessControlEnumerableUpgradeable } from "@openzeppelin-upgrades/contracts/access/extensions/AccessControlEnumerableUpgradeable.sol";

import { IDETH } from "@/contracts/L1/interfaces/IDETH.sol";
import { IStakingManager } from "@/contracts/L1/interfaces/IStakingManager.sol";
import { IUnstakeRequestsManager } from "@/contracts/L1/interfaces/IUnstakeRequestsManager.sol";


contract DETH is Initializable, AccessControlEnumerableUpgradeable, ERC20PermitUpgradeable, IDETH {
    IStakingManager public stakingContract;

    IUnstakeRequestsManager public unstakeRequestsManagerContract;

    struct Init {
        address admin;
        IStakingManager staking;
        IUnstakeRequestsManager unstakeRequestsManager;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(Init memory init) external initializer {
        __AccessControlEnumerable_init();
        __ERC20_init("dETH", "dETH");
        __ERC20Permit_init("dETH");

        _grantRole(DEFAULT_ADMIN_ROLE, init.admin);
        stakingContract = init.staking;
        unstakeRequestsManagerContract = init.unstakeRequestsManager;
    }

    function mint(address staker, uint256 amount) external {
        if (msg.sender != address(stakingContract)) {
            revert NotStakingManagerContract();
        }
        _mint(staker, amount);
    }

    function burn(uint256 amount) external {
        if (msg.sender != address(unstakeRequestsManagerContract)) {
            revert NotUnstakeRequestsManagerContract();
        }
        _burn(msg.sender, amount);
    }

    function nonces(address owner)
        public
        view
        virtual
        override(ERC20PermitUpgradeable, IERC20Permit)
        returns (uint256)
    {
        return ERC20PermitUpgradeable.nonces(owner);
    }
}

