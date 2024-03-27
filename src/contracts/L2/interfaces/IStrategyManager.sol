// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "./IStrategy.sol";
import "./ISlashManager.sol";
import "./IDelegationManager.sol";


interface IStrategyManager {
    event Deposit(address staker, IERC20 weth, IStrategy strategy, uint256 shares);

    event UpdatedThirdPartyTransfersForbidden(IStrategy strategy, bool value);

    event StrategyWhitelisterChanged(address previousAddress, address newAddress);

    event StrategyAddedToDepositWhitelist(IStrategy strategy);

    event StrategyRemovedFromDepositWhitelist(IStrategy strategy);

    event MigrateRelatedL1StakerShares(address staker, IStrategy strategy, uint256 shares);

    function depositWETHIntoStrategy(IStrategy strategy, IERC20 weth, uint256 amount) external returns (uint256 shares);

    function depositETHIntoStrategy(IStrategy strategy, uint256 amount) external returns (uint256 shares);

    function depositWETHIntoStrategyWithSignature(
        IStrategy strategy,
        IERC20 weth,
        uint256 amount,
        address staker,
        uint256 expiry,
        bytes memory signature
    ) external returns (uint256 shares);

    function depositETHIntoStrategyWithSignature(
        IStrategy strategy,
        uint256 amount,
        address staker,
        uint256 expiry,
        bytes memory signature
    ) external returns (uint256 shares);

    function removeShares(address staker, IStrategy strategy, uint256 shares) external;

    function addShares(address staker, IERC20 weth, IStrategy strategy, uint256 shares) external;
    
    function withdrawSharesAsWeth(address recipient, IStrategy strategy, uint256 shares, IERC20 weth) external;

    function stakerStrategyShares(address user, IStrategy strategy) external view returns (uint256 shares);

    function getDeposits(address staker) external view returns (IStrategy[] memory, uint256[] memory);

    function stakerStrategyListLength(address staker) external view returns (uint256);

    function addStrategiesToDepositWhitelist(
        IStrategy[] calldata strategiesToWhitelist,
        bool[] calldata thirdPartyTransfersForbiddenValues
    ) external;

    function removeStrategiesFromDepositWhitelist(IStrategy[] calldata strategiesToRemoveFromWhitelist) external;

    function delegation() external view returns (IDelegationManager);

    function slasher() external view returns (ISlashManager);

    function strategyWhitelister() external view returns (address);

    function thirdPartyTransfersForbidden(IStrategy strategy) external view returns (bool);

    struct DeprecatedStruct_WithdrawerAndNonce {
        address withdrawer;
        uint96 nonce;
    }

    struct DeprecatedStruct_QueuedWithdrawal {
        IStrategy[] strategies;
        uint256[] shares;
        address staker;
        DeprecatedStruct_WithdrawerAndNonce withdrawerAndNonce;
        uint32 withdrawalStartBlock;
        address delegatedAddress;
    }

    function migrateQueuedWithdrawal(DeprecatedStruct_QueuedWithdrawal memory queuedWithdrawal) external returns (bool, bytes32);

    function calculateWithdrawalRoot(DeprecatedStruct_QueuedWithdrawal memory queuedWithdrawal) external pure returns (bytes32);

    function  migrateRelatedL1StakerShares(address staker, IStrategy strategy, uint256 shares) external returns (bool);
}
