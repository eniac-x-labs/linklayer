// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "./IFundingPoool.sol";
import "./ISlasher.sol";
import "./IDelegationManager.sol";

interface IFundingPooolManager {

    event Deposit(address staker, IFundingPoool FundingPool, uint256 shares);

    event FundingPoolWhitelisterChanged(address previousAddress, address newAddress);

    event FundingPoolAddedToDepositWhitelist(IFundingPoool FundingPool);

    event FundingPoolRemovedFromDepositWhitelist(IFundingPoool FundingPool);

    function depositIntoFundingPool(IFundingPoool FundingPool, uint256 amount) external returns (uint256 shares);

    function removeShares(address staker, IFundingPoool FundingPool, uint256 shares) external;

    function addShares(address staker, IFundingPoool FundingPool, uint256 shares) external;

    function withdrawSharesAsEths(address recipient, IFundingPoool FundingPool, uint256 shares) external;

    function withdrawSharesAsTokens(address recipient, IFundingPoool FundingPool, uint256 shares, IERC20 token) external;

    function stakerFundingPoolShares(address user, IFundingPoool FundingPool) external view returns (uint256 shares);

    function getDeposits(address staker) external view returns (IFundingPoool[] memory, uint256[] memory);

    function stakerFundingPoolListLength(address staker) external view returns (uint256);

    function addFundingPoolsToDepositWhitelist(IFundingPoool[] calldata FundingPoolsToWhitelist) external;

    function removeFundingPoolsFromDepositWhitelist(IFundingPoool[] calldata FundingPoolsToRemoveFromWhitelist) external;

    function delegation() external view returns (IDelegationManager);

    function slasher() external view returns (ISlasher);

    function FundingPoolWhitelister() external view returns (address);

    struct DeprecatedStruct_WithdrawerAndNonce {
        address withdrawer;
        uint96 nonce;
    }

    struct DeprecatedStruct_QueuedWithdrawal {
        IFundingPoool[] fundingPools;
        uint256[] shares;
        address staker;
        DeprecatedStruct_WithdrawerAndNonce withdrawerAndNonce;
        uint32 withdrawalStartBlock;
        address delegatedAddress;
    }

    function migrateQueuedWithdrawal(DeprecatedStruct_QueuedWithdrawal memory queuedWithdrawal) external returns (bool, bytes32);

    function calculateWithdrawalRoot(DeprecatedStruct_QueuedWithdrawal memory queuedWithdrawal) external pure returns (bytes32);
}
