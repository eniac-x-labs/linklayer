// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20PermitUpgradeable, IERC20Permit } from "@openzeppelin-upgrades/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20Upgradeable, IERC20} from "@openzeppelin-upgrades/contracts/token/ERC20/ERC20Upgradeable.sol";

import {L1Base} from "@/contracts/L1/core/L1Base.sol";
import { IDETH } from "@/contracts/L1/interfaces/IDETH.sol";
import "../../libraries/SafeCall.sol";


contract DETH is L1Base, ERC20PermitUpgradeable, IDETH {

    address public l2ShareAddress;
    address public bridgeAddress;

    struct Init {
        address admin;
        address l2ShareAddress;
        address bridgeAddress;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(Init memory init) external initializer {
        __L1Base_init(init.admin);

        __ERC20_init("dETH", "dETH");
        __ERC20Permit_init("dETH");

        l2ShareAddress = init.l2ShareAddress;
        bridgeAddress = init.bridgeAddress;
    }

    function mint(address staker, uint256 amount) external {
        if (msg.sender != getLocator().stakingManager()) {
            revert NotStakingManagerContract();
        }
        _mint(staker, amount);
    }

    function batchMint(BatchMint[] calldata batcher) external {
        if (msg.sender != getLocator().stakingManager()) {
            revert NotStakingManagerContract();
        }
        for (uint256 i =0; i < batcher.length; i++) {
            _mint(batcher[i].staker, batcher[i].amount);
        }
    }

    function burn(uint256 amount) external {
        if (msg.sender != getLocator().unStakingRequestsManager()) {
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

    function transfer(
        address to,
        uint256 value
    ) public override(ERC20Upgradeable, IERC20) returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        bool success = SafeCall.callWithMinGas(
            bridgeAddress,
            200000,
            0,
            abi.encodeWithSignature("BridgeInitiateStakingMessage(address,address,uint256)", owner, to, value)
        );
        if (!success) {
            revert BridgeStakingMessageInitFailed();
        }
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override(ERC20Upgradeable, IERC20) returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        bool success = SafeCall.callWithMinGas(
            bridgeAddress,
            200000,
            0,
            abi.encodeWithSignature("BridgeInitiateStakingMessage(address,address,uint256)", from, to, value)
        );
        if (!success) {
            revert BridgeStakingMessageInitFailed();
        }
        return true;
    }
}

