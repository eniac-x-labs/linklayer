// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20PermitUpgradeable, IERC20Permit } from "@openzeppelin-upgrades/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

import {L1Base} from "@/contracts/L1/core/L1Base.sol";
import { IDETH } from "@/contracts/L1/interfaces/IDETH.sol";

contract DETH is L1Base, ERC20PermitUpgradeable, IDETH {

    address public l2ShareAddress;

    struct Init {
        address admin;
        address l2ShareAddress;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(Init memory init) external initializer {
        __L1Base_init(init.admin);

        __ERC20_init("dETH", "dETH");
        __ERC20Permit_init("dETH");

        l2ShareAddress = init.l2ShareAddress;
    }

    function mint(address staker, uint256 amount) external {
        if (msg.sender != locator.stakingManager()) {
            revert NotStakingManagerContract();
        }
        _mint(staker, amount);
    }

    function batchMint(BatchMint[] calldata batcher) external {
        if (msg.sender != l2ShareAddress) {
            revert NotL2ShareAddress();
        }
        for (uint256 i =0; i < batcher.length; i++) {
            _mint(batcher[i].staker, batcher[i].amount);
        }
    }

    function burn(uint256 amount) external {
        if (msg.sender != locator.unStakingRequestsManager()) {
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

