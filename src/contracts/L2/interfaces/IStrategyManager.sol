// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStrategyManager {
    event Deposit(address staker, IERC20 weth, address strategy, uint256 shares);

    event UpdatedThirdPartyTransfersForbidden(address strategy, bool value);

    event StrategyWhitelisterChanged(address previousAddress, address newAddress);

    event StrategyAddedToDepositWhitelist(address strategy);

    event StrategyRemovedFromDepositWhitelist(address strategy);

    event MigrateRelatedL1StakerShares(address staker, address strategy, uint256 shares, uint256 l1UnStakeMessageNonce);

    function depositWETHIntoStrategy(address strategy, IERC20 weth, uint256 amount) external returns (uint256 shares);

    function depositETHIntoStrategy(address strategy) external payable returns (uint256 shares);

    function depositWETHIntoStrategyWithSignature(
        address strategy,
        IERC20 weth,
        uint256 amount,
        address staker,
        uint256 expiry,
        bytes memory signature
    ) external returns (uint256 shares);

    function depositETHIntoStrategyWithSignature(
        address strategy,
        uint256 amount,
        address staker,
        uint256 expiry,
        bytes memory signature
    ) external returns (uint256 shares);

    function removeShares(address staker, address strategy, uint256 shares) external;

    function addShares(address staker, IERC20 weth, address strategy, uint256 shares) external;
    
    function withdrawSharesAsWeth(address recipient, address strategy, uint256 shares, IERC20 weth) external;

    function getStakerStrategyShares(address user, address strategy) external view returns (uint256 shares);

    function getDeposits(address staker) external view returns (address[] memory, uint256[] memory);

    function stakerStrategyListLength(address staker) external view returns (uint256);

    function addStrategiesToDepositWhitelist(
        address[] calldata strategiesToWhitelist,
        bool[] calldata thirdPartyTransfersForbiddenValues
    ) external;

    function removeStrategiesFromDepositWhitelist(address[] calldata strategiesToRemoveFromWhitelist) external;

    function strategyWhitelister() external view returns (address);

    function thirdPartyTransfersForbidden(address strategy) external view returns (bool);

    struct DeprecatedStruct_WithdrawerAndNonce {
        address withdrawer;
        uint96 nonce;
    }

    struct DeprecatedStruct_QueuedWithdrawal {
        address[] strategies;
        uint256[] shares;
        address staker;
        DeprecatedStruct_WithdrawerAndNonce withdrawerAndNonce;
        uint32 withdrawalStartBlock;
        address delegatedAddress;
    }

    function migrateQueuedWithdrawal(DeprecatedStruct_QueuedWithdrawal memory queuedWithdrawal) external returns (bool, bytes32);

    function calculateWithdrawalRoot(DeprecatedStruct_QueuedWithdrawal memory queuedWithdrawal) external pure returns (bytes32);

    function migrateRelatedL1StakerShares(address staker, address strategy, uint256 shares, uint256 l1UnStakeMessageNonce) external returns (bool);

    function getStakerStrategyL1BackShares(address staker, address strategy) external returns (uint256);

    function updateStakerStrategyL1BackShares(address staker, address strategy, uint256 shares) external;

    function transferStakerStrategyShares(address strategy, address from, address to, uint256 shares) external returns (bool);
}
