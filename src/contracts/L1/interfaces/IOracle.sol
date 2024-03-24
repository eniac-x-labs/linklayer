// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct OracleRecord {
    uint64 updateStartBlock;
    uint64 updateEndBlock;
    uint64 currentNumValidatorsNotWithdrawable;
    uint64 cumulativeNumValidatorsWithdrawable;
    uint128 windowWithdrawnPrincipalAmount;
    uint128 windowWithdrawnRewardAmount;
    uint128 currentTotalValidatorBalance;
    uint128 cumulativeProcessedDepositAmount;
}

interface IOracleWrite {
    function receiveRecord(OracleRecord calldata record) external;
}

interface IOracleReadRecord {
    function latestRecord() external view returns (OracleRecord calldata);
    function recordAt(uint256 idx) external view returns (OracleRecord calldata);
    function numRecords() external view returns (uint256);
}

interface IOracleReadPending {
    function pendingUpdate() external view returns (OracleRecord calldata);
    function hasPendingUpdate() external view returns (bool);
}

interface IOracleRead is IOracleReadRecord, IOracleReadPending {}

interface IOracleManager {
    function setOracleUpdater(address newUpdater) external;
}

interface IOracle is IOracleWrite, IOracleRead, IOracleManager {
    error CannotUpdateWhileUpdatePending();
    error CannotModifyInitialRecord();
    error InvalidConfiguration();
    error InvalidRecordModification();
    error InvalidUpdateStartBlock(uint256 wantUpdateStartBlock, uint256 gotUpdateStartBlock);
    error InvalidUpdateEndBeforeStartBlock(uint256 end, uint256 start);
    error InvalidUpdateMoreDepositsProcessedThanSent(uint256 processed, uint256 sent);
    error InvalidUpdateMoreValidatorsThanInitiated(uint256 numValidatorsOnRecord, uint256 numInitiatedValidators);
    error NoUpdatePending();
    error Paused();
    error RecordDoesNotExist(uint256 idx);
    error UnauthorizedOracleUpdater(address sender, address oracleUpdater);
    error UpdateEndBlockNumberNotFinal(uint256 updateFinalizingBlock);
    error ZeroAddress();

    event OracleRecordAdded(uint256 indexed index, OracleRecord record);
    event OracleRecordModified(uint256 indexed index, OracleRecord record);
    event OraclePendingUpdateRejected(OracleRecord pendingUpdate);
    event OracleRecordFailedSanityCheck(
        bytes32 indexed reasonHash, string reason, OracleRecord record, uint256 value, uint256 bound
    );
}
