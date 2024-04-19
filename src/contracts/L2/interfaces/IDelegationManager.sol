// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISignatureUtils} from "./ISignatureUtils.sol";
import {IStrategyManager} from "./IStrategyManager.sol";

interface IDelegationManager is ISignatureUtils {
    enum OperatorType {
        SocialNode,
        GameNode,
        MpcNode,
        DaNode,
        TradingNode,
        AiNode,
        otherNode
    }

    struct OperatorDetails {
        address earningsReceiver;
        address delegationApprover;
        uint32 stakerOptOutWindowBlocks;
        OperatorType operatorType;
    }

    struct StakerDelegation {
        address staker;
        address operator;
        uint256 nonce;
        uint256 expiry;
    }

    struct DelegationApproval {
        address staker;
        address operator;
        bytes32 salt;
        uint256 expiry;
    }

    struct Withdrawal {
        address staker;
        address delegatedTo;
        address withdrawer;
        uint256 nonce;
        uint32 startBlock;
        address[] strategies;
        uint256[] shares;
    }

    struct QueuedWithdrawalParams {
        address[] strategies;
        uint256[] shares;
        address withdrawer;
    }

    event OperatorRegistered(address indexed operator, OperatorDetails operatorDetails);

    event OperatorDetailsModified(address indexed operator, OperatorDetails newOperatorDetails);

    event OperatorNodeUrlUpdated(address indexed operator, string metadataURI);

    event OperatorSharesIncreased(address indexed operator, address staker, address strategy, uint256 shares);

    event OperatorSharesDecreased(address indexed operator, address staker, address strategy, uint256 shares);

    event StakerDelegated(address indexed staker, address indexed operator);

    event StakerUndelegated(address indexed staker, address indexed operator);

    event StakerForceUndelegated(address indexed staker, address indexed operator);

    event WithdrawalQueued(bytes32 withdrawalRoot, Withdrawal withdrawal);

    event WithdrawalCompleted(address operator, address staker, address strategy, uint256 shares);

    event WithdrawalMigrated(bytes32 oldWithdrawalRoot, bytes32 newWithdrawalRoot);
    
    event MinWithdrawalDelayBlocksSet(uint256 previousValue, uint256 newValue);

    event StrategyWithdrawalDelayBlocksSet(address strategy, uint256 previousValue, uint256 newValue);

    function registerAsOperator(
        OperatorDetails calldata registeringOperatorDetails,
        string calldata metadataURI
    ) external;

    function modifyOperatorDetails(OperatorDetails calldata newOperatorDetails) external;

    function updateOperatorNodeUrl(string calldata metadataURI) external;

    function delegateTo(
        address operator,
        SignatureWithExpiry memory approverSignatureAndExpiry,
        bytes32 approverSalt
    ) external;

    function delegateToBySignature(
        address staker,
        address operator,
        SignatureWithExpiry memory stakerSignatureAndExpiry,
        SignatureWithExpiry memory approverSignatureAndExpiry,
        bytes32 approverSalt
    ) external;

    function undelegate(address staker) external returns (bytes32[] memory withdrawalRoot);

    function queueWithdrawals(
        QueuedWithdrawalParams[] calldata queuedWithdrawalParams
    ) external returns (bytes32[] memory);

    function completeQueuedWithdrawal(
        Withdrawal calldata withdrawal,
        IERC20 weth,
        uint256 middlewareTimesIndex,
        bool receiveAsTokens
    ) external;

    function completeQueuedWithdrawals(
        Withdrawal[] calldata withdrawals,
        IERC20 weth,
        uint256[] calldata middlewareTimesIndexes,
        bool[] calldata receiveAsTokens
    ) external;

    function increaseDelegatedShares(
        address staker,
        address strategy,
        uint256 shares
    ) external;

    function decreaseDelegatedShares(
        address staker,
        address strategy,
        uint256 shares
    ) external;

    function delegatedTo(address staker) external view returns (address);

    function operatorDetails(address operator) external view returns (OperatorDetails memory);

    function earningsReceiver(address operator) external view returns (address);

    function delegationApprover(address operator) external view returns (address);

    function stakerOptOutWindowBlocks(address operator) external view returns (uint256);

    function getOperatorShares(
        address operator,
        address[] memory strategies
    ) external view returns (uint256[] memory);

    function getWithdrawalDelay(address[] calldata strategies) external view returns (uint256);

    function operatorShares(address operator, address strategy) external view returns (uint256);

    function isDelegated(address staker) external view returns (bool);

    function isOperator(address operator) external view returns (bool);

    function stakerNonce(address staker) external view returns (uint256);

    function delegationApproverSaltIsSpent(address _delegationApprover, bytes32 salt) external view returns (bool);

    function minWithdrawalDelayBlocks() external view returns (uint256);

    function strategyWithdrawalDelayBlocks(address strategy) external view returns (uint256);

    function calculateCurrentStakerDelegationDigestHash(
        address staker,
        address operator,
        uint256 expiry
    ) external view returns (bytes32);

    function calculateStakerDelegationDigestHash(
        address staker,
        uint256 _stakerNonce,
        address operator,
        uint256 expiry
    ) external view returns (bytes32);

    function calculateDelegationApprovalDigestHash(
        address staker,
        address operator,
        address _delegationApprover,
        bytes32 approverSalt,
        uint256 expiry
    ) external view returns (bytes32);

    function DOMAIN_TYPEHASH() external view returns (bytes32);

    function STAKER_DELEGATION_TYPEHASH() external view returns (bytes32);

    function DELEGATION_APPROVAL_TYPEHASH() external view returns (bytes32);

    function domainSeparator() external view returns (bytes32);

    function cumulativeWithdrawalsQueued(address staker) external view returns (uint256);

    function calculateWithdrawalRoot(Withdrawal memory withdrawal) external pure returns (bytes32);

    function migrateQueuedWithdrawals(IStrategyManager.DeprecatedStruct_QueuedWithdrawal[] memory withdrawalsToQueue) external;
}
