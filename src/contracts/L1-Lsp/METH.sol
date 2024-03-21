// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from
    "@openzeppelin-upgrades/contracts/access/AccessControlUpgradeable.sol";
// import {AccessControlEnumerable} from "openzeppelin/access/AccessControlEnumerable.sol";
import {
    ERC20PermitUpgradeable,
    IERC20PermitUpgradeable
} from "@openzeppelin-upgrades/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

import {IDETH} from "@/contracts/L1-Lsp/interfaces/IDETH.sol";
import {IStaking} from "./interfaces/IStaking.sol";
import {IUnstakeRequestsManager} from "./interfaces/IUnstakeRequestsManager.sol";

/// @title dETH
/// @notice dETH is the ERC20 LSD token for the protocol.
contract dETH is Initializable, AccessControlUpgradeable, ERC20PermitUpgradeable, IDETH {
    // Errors.
    error NotStakingContract();
    error NotUnstakeRequestsManagerContract();

    /// @notice The staking contract which has permissions to mint tokens.
    IStaking public stakingContract;

    /// @notice The unstake requests manager contract which has permissions to burn tokens.
    IUnstakeRequestsManager public unstakeRequestsManagerContract;

    /// @notice Configuration for contract initialization.
    struct Init {
        address admin;
        IStaking staking;
        IUnstakeRequestsManager unstakeRequestsManager;
    }

    constructor() {
        _disableInitializers();
    }

    /// @notice Inititalizes the contract.
    /// @dev MUST be called during the contract upgrade to set up the proxies state.
    function initialize(Init memory init) external initializer {
        // __AccessControlEnumerable_init();
        __ERC20_init("dETH", "dETH");
        __ERC20Permit_init("dETH");

        _grantRole(DEFAULT_ADMIN_ROLE, init.admin);
        stakingContract = init.staking;
        unstakeRequestsManagerContract = init.unstakeRequestsManager;
    }

    /// @inheritdoc IDETH
    /// @dev Expected to be called during the stake operation.
    function mint(address staker, uint256 amount) external {
        if (msg.sender != address(stakingContract)) {
            revert NotStakingContract();
        }

        _mint(staker, amount);
    }

    /// @inheritdoc IDETH
    /// @dev Expected to be called when a user has claimed their unstake request.
    function burn(uint256 amount) external {
        if (msg.sender != address(unstakeRequestsManagerContract)) {
            revert NotUnstakeRequestsManagerContract();
        }

        _burn(msg.sender, amount);
    }

    /// @dev See {IERC20Permit-nonces}.
    function nonces(address owner)
        public
        view
        virtual
        override(ERC20PermitUpgradeable, IERC20PermitUpgradeable)
        returns (uint256)
    {
        return ERC20PermitUpgradeable.nonces(owner);
    }
}
