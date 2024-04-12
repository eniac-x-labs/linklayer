// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {L1Base} from "@/contracts/L1/core/L1Base.sol";
import {OracleRecord, IOracleManager} from "../interfaces/IOracleManager.sol";
import { IOracleQuorumManager } from "../interfaces/IOracleQuorumManager.sol";


contract OracleQuorumManager is
    L1Base,
    IOracleQuorumManager
{
    bytes32 public constant QUORUM_MANAGER_ROLE = keccak256("QUORUM_MANAGER_ROLE");

    bytes32 public constant REPORTER_MODIFIER_ROLE = keccak256("REPORTER_MODIFIER_ROLE");

    bytes32 public constant SERVICE_ORACLE_REPORTER = keccak256("SERVICE_ORACLE_REPORTER");

    uint16 internal constant _BASIS_POINTS_DENOMINATOR = 10000;

    mapping(uint64 block => mapping(address reporter => bytes32 recordHash)) public reporterRecordHashesByBlock;

    mapping(uint64 block => mapping(bytes32 recordHash => uint256)) public recordHashCountByBlock;

    uint64 public targetReportWindowBlocks;

    uint16 public absoluteThreshold;

    uint16 public relativeThresholdBasisPoints;

    struct Init {
        address admin;
        address reporterModifier;
        address manager;
        address[] allowedReporters;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(Init memory init) external initializer {
        __L1Base_init(init.admin);
        _grantRole(REPORTER_MODIFIER_ROLE, init.reporterModifier);
        _setRoleAdmin(SERVICE_ORACLE_REPORTER, REPORTER_MODIFIER_ROLE);

        _grantRole(QUORUM_MANAGER_ROLE, init.manager);

        uint256 len = init.allowedReporters.length;
        for (uint256 i = 0; i < len; i++) {
            _grantRole(SERVICE_ORACLE_REPORTER, init.allowedReporters[i]);
        }

        targetReportWindowBlocks = 8 hours / 12 seconds;

        absoluteThreshold = 1;
        relativeThresholdBasisPoints = 0;
    }

    function _hasReachedQuroum(uint64 blockNumber, bytes32 recordHash) internal view returns (bool) {
        uint256 numReports = recordHashCountByBlock[blockNumber][recordHash];
        uint256 numReporters = getRoleMemberCount(SERVICE_ORACLE_REPORTER);

        return (numReports >= absoluteThreshold)
            && (numReports * _BASIS_POINTS_DENOMINATOR >= numReporters * relativeThresholdBasisPoints);
    }

    function _wasReceivedByOracle(uint256 updateEndBlock) internal view returns (bool) {
        return getOracle().latestRecord().updateEndBlock >= updateEndBlock
            || (getOracle().hasPendingUpdate() && getOracle().pendingUpdate().updateEndBlock >= updateEndBlock);
    }

    function recordHashByBlockAndSender(uint64 blockNumber, address sender) external view returns (bytes32) {
        return reporterRecordHashesByBlock[blockNumber][sender];
    }

    function _trackReceivedRecord(address reporter, OracleRecord calldata record) internal returns (bytes32) {
        bytes32 newHash = keccak256(abi.encode(record));
        emit ReportReceived(record.updateEndBlock, reporter, newHash, record);

        bytes32 previousHash = reporterRecordHashesByBlock[record.updateEndBlock][reporter];
        if (newHash == previousHash) {
            return newHash;
        }

        if (previousHash != 0) {
            recordHashCountByBlock[record.updateEndBlock][previousHash] -= 1;
        }

        recordHashCountByBlock[record.updateEndBlock][newHash] += 1;
        reporterRecordHashesByBlock[record.updateEndBlock][reporter] = newHash;

        return newHash;
    }

    function receiveRecord(OracleRecord calldata record,  address bridge, address l2Strategy, uint256 sourceChainId, uint256 destChainId) external onlyRole(SERVICE_ORACLE_REPORTER) {
        bytes32 recordHash = _trackReceivedRecord(msg.sender, record);

        if (!_hasReachedQuroum(record.updateEndBlock, recordHash)) {
            return;
        }

        if (_wasReceivedByOracle(record.updateEndBlock)) {
            return;
        }

        emit ReportQuorumReached(record.updateEndBlock);

        try getOracle().receiveRecord(record, bridge, l2Strategy, sourceChainId, destChainId) {}
        catch (bytes memory reason) {
            emit OracleRecordReceivedError(reason);
        }
    }

    function setTargetReportWindowBlocks(uint64 newTargetReportWindowBlocks) external onlyRole(QUORUM_MANAGER_ROLE) {
        targetReportWindowBlocks = newTargetReportWindowBlocks;
        emit ProtocolConfigChanged(
            this.setTargetReportWindowBlocks.selector,
            "setTargetReportWindowBlocks(uint64)",
            abi.encode(newTargetReportWindowBlocks)
        );
    }

    function setQuorumThresholds(uint16 absoluteThreshold_, uint16 relativeThresholdBasisPoints_)
        external
        onlyRole(QUORUM_MANAGER_ROLE)
    {
        if (relativeThresholdBasisPoints_ > _BASIS_POINTS_DENOMINATOR) {
            revert RelativeThresholdExceedsOne();
        }

        emit ProtocolConfigChanged(
            this.setQuorumThresholds.selector,
            "setQuorumThresholds(uint16,uint16)",
            abi.encode(absoluteThreshold_, relativeThresholdBasisPoints_)
        );
        absoluteThreshold = absoluteThreshold_;
        relativeThresholdBasisPoints = relativeThresholdBasisPoints_;
    }

    function getOracle()internal view returns (IOracleManager) {
        return IOracleManager(getLocator().oracleManager());
    }
}
