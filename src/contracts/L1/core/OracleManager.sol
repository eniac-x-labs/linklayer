// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import {L1Base} from "@/contracts/L1/core/L1Base.sol";
import {
    IOracleManager,
    IOracleReadRecord,
    IOracleReadPending,
    IOracleWrite,
    OracleRecord
} from "../interfaces/IOracleManager.sol";
import { IReturnsAggregator } from "../interfaces/IReturnsAggregator.sol";
import { IL1Pauser } from "../../access/interface/IL1Pauser.sol";
import { OracleManagerStorage } from "./OracleManagerStorage.sol";


contract OracleManager is L1Base, OracleManagerStorage {
    bool public hasPendingUpdate;

    OracleRecord internal _pendingUpdate;

    uint256 public finalizationBlockNumberDelta;

    address public oracleUpdater;

    uint256 public minDepositPerValidator;

    uint256 public maxDepositPerValidator;

    uint40 public minConsensusLayerGainPerBlockPPT;

    uint40 public maxConsensusLayerGainPerBlockPPT;

    uint24 public maxConsensusLayerLossPPM;

    uint16 public minReportSizeBlocks;

    uint24 internal constant _PPM_DENOMINATOR = 1e6;

    uint40 internal constant _PPT_DENOMINATOR = 1e12;

    struct Init {
        address admin;
        address manager;
        address oracleUpdater;
        address pendingResolver;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(Init memory init) external initializer {
        __L1Base_init(init.admin);
        _grantRole(ORACLE_MANAGER_ROLE, init.manager);
        _grantRole(ORACLE_PENDING_UPDATE_RESOLVER_ROLE, init.pendingResolver);

        oracleUpdater = init.oracleUpdater;

        finalizationBlockNumberDelta = 64;

        minReportSizeBlocks = 100;
        minDepositPerValidator = 32 ether;
        maxDepositPerValidator = 32 ether;

        maxConsensusLayerGainPerBlockPPT = 190250; // 10x approximate rate
        minConsensusLayerGainPerBlockPPT = 1903; // 0.1x approximate rate

        maxConsensusLayerLossPPM = 1000;

   }
    function initRecord()external onlyRole(ORACLE_PENDING_UPDATE_RESOLVER_ROLE) {
        _pushRecord(OracleRecord(0, uint64(getStakingManager().initializationBlockNumber()), 0, 0, 0, 0, 0, 0), msg.sender, msg.sender, 0, 0);
    }
    function receiveRecord(OracleRecord calldata newRecord, address bridge, address l2Strategy, uint256 sourceChainId, uint256 destChainId) external {
        if (IL1Pauser(getLocator().pauser()).isSubmitOracleRecordsPaused()) {
            revert Paused();
        }

        if (msg.sender != oracleUpdater) {
            revert UnauthorizedOracleUpdater(msg.sender, oracleUpdater);
        }

        if (hasPendingUpdate) {
            revert CannotUpdateWhileUpdatePending();
        }

        validateUpdate(_records.length - 1, newRecord);

        uint256 updateFinalizingBlock = newRecord.updateEndBlock + finalizationBlockNumberDelta;
        if (block.number < updateFinalizingBlock) {
            revert UpdateEndBlockNumberNotFinal(updateFinalizingBlock);
        }

        (string memory rejectionReason, uint256 value, uint256 bound) = sanityCheckUpdate(latestRecord(), newRecord);
        if (bytes(rejectionReason).length > 0) {
            _pendingUpdate = newRecord;
            hasPendingUpdate = true;
            emit OracleRecordFailedSanityCheck({
                reasonHash: keccak256(bytes(rejectionReason)),
                reason: rejectionReason,
                record: newRecord,
                value: value,
                bound: bound
            });

            IL1Pauser(getLocator().pauser()).pauseAll();
            return;
        }
        _pushRecord(newRecord, bridge, l2Strategy, sourceChainId, destChainId);
    }

    function modifyExistingRecord(uint256 idx, OracleRecord calldata record, address bridge, address l2Strategy, uint256 sourceChainId, uint256 destChainId) external onlyRole(ORACLE_MODIFIER_ROLE) {
        if (idx == 0) {
            revert CannotModifyInitialRecord();
        }

        if (idx >= _records.length) {
            revert RecordDoesNotExist(idx);
        }

        OracleRecord storage existingRecord = _records[idx];
        if (
            existingRecord.updateStartBlock != record.updateStartBlock
                || existingRecord.updateEndBlock != record.updateEndBlock
        ) {
            revert InvalidRecordModification();
        }

        validateUpdate(idx - 1, record);

        uint256 missingRewards = 0;
        uint256 missingPrincipals = 0;

        if (record.windowWithdrawnRewardAmount > existingRecord.windowWithdrawnRewardAmount) {
            missingRewards = record.windowWithdrawnRewardAmount - existingRecord.windowWithdrawnRewardAmount;
        }
        if (record.windowWithdrawnPrincipalAmount > existingRecord.windowWithdrawnPrincipalAmount) {
            missingPrincipals = record.windowWithdrawnPrincipalAmount - existingRecord.windowWithdrawnPrincipalAmount;
        }

        _records[idx] = record;
        emit OracleRecordModified(idx, record);

        if (missingRewards > 0 || missingPrincipals > 0) {
            IReturnsAggregator(getLocator().returnsAggregator()).processReturns({
                rewardAmount: missingRewards,
                principalAmount: missingPrincipals,
                shouldIncludeELRewards: false,
                bridge: bridge,
                l2Strategy: l2Strategy,
                sourceChainId: sourceChainId,
                destChainId: destChainId
            });
        }
    }

    function validateUpdate(uint256 prevRecordIndex, OracleRecord calldata newRecord) public view {
        OracleRecord storage prevRecord = _records[prevRecordIndex];
        if (newRecord.updateEndBlock <= newRecord.updateStartBlock) {
            revert InvalidUpdateEndBeforeStartBlock(newRecord.updateEndBlock, newRecord.updateStartBlock);
        }

        if (newRecord.updateStartBlock != prevRecord.updateEndBlock + 1) {
            revert InvalidUpdateStartBlock(prevRecord.updateEndBlock + 1, newRecord.updateStartBlock);
        }

        if (newRecord.cumulativeProcessedDepositAmount > getStakingManager().totalDepositedInValidators()) {
            revert InvalidUpdateMoreDepositsProcessedThanSent(
                newRecord.cumulativeProcessedDepositAmount, getStakingManager().totalDepositedInValidators()
            );
        }

        if (
            uint256(newRecord.currentNumValidatorsNotWithdrawable)
                + uint256(newRecord.cumulativeNumValidatorsWithdrawable) > getStakingManager().numInitiatedValidators()
        ) {
            revert InvalidUpdateMoreValidatorsThanInitiated(
                newRecord.currentNumValidatorsNotWithdrawable + newRecord.cumulativeNumValidatorsWithdrawable,
                getStakingManager().numInitiatedValidators()
            );
        }
    }

    function sanityCheckUpdate(OracleRecord memory prevRecord, OracleRecord calldata newRecord)
        public
        view
        returns (string memory, uint256, uint256)
    {
        uint64 reportSize = newRecord.updateEndBlock - newRecord.updateStartBlock + 1;
        {
            if (reportSize < minReportSizeBlocks) {
                return ("Report blocks below minimum bound", reportSize, minReportSizeBlocks);
            }
        }
        {
            if (newRecord.cumulativeNumValidatorsWithdrawable < prevRecord.cumulativeNumValidatorsWithdrawable) {
                return (
                    "Cumulative number of withdrawable validators decreased",
                    newRecord.cumulativeNumValidatorsWithdrawable,
                    prevRecord.cumulativeNumValidatorsWithdrawable
                );
            }
            {
                uint256 prevNumValidators =
                    prevRecord.currentNumValidatorsNotWithdrawable + prevRecord.cumulativeNumValidatorsWithdrawable;
                uint256 newNumValidators =
                    newRecord.currentNumValidatorsNotWithdrawable + newRecord.cumulativeNumValidatorsWithdrawable;

                if (newNumValidators < prevNumValidators) {
                    return ("Total number of validators decreased", newNumValidators, prevNumValidators);
                }
            }
        }

        {
            if (newRecord.cumulativeProcessedDepositAmount < prevRecord.cumulativeProcessedDepositAmount) {
                return (
                    "Processed deposit amount decreased",
                    newRecord.cumulativeProcessedDepositAmount,
                    prevRecord.cumulativeProcessedDepositAmount
                );
            }

            uint256 newDeposits =
                (newRecord.cumulativeProcessedDepositAmount - prevRecord.cumulativeProcessedDepositAmount);
            uint256 newValidators = (
                newRecord.currentNumValidatorsNotWithdrawable + newRecord.cumulativeNumValidatorsWithdrawable
                    - prevRecord.currentNumValidatorsNotWithdrawable - prevRecord.cumulativeNumValidatorsWithdrawable
            );

            if (newDeposits < newValidators * minDepositPerValidator) {
                return (
                    "New deposits below min deposit per validator", newDeposits, newValidators * minDepositPerValidator
                );
            }

            if (newDeposits > newValidators * maxDepositPerValidator) {
                return (
                    "New deposits above max deposit per validator", newDeposits, newValidators * maxDepositPerValidator
                );
            }
        }

        {
            uint256 baselineGrossCLBalance = prevRecord.currentTotalValidatorBalance
                + (newRecord.cumulativeProcessedDepositAmount - prevRecord.cumulativeProcessedDepositAmount);

            uint256 newGrossCLBalance = newRecord.currentTotalValidatorBalance
                + newRecord.windowWithdrawnPrincipalAmount + newRecord.windowWithdrawnRewardAmount;

            {
                uint256 lowerBound = baselineGrossCLBalance
                    - Math.mulDiv(maxConsensusLayerLossPPM, baselineGrossCLBalance, _PPM_DENOMINATOR)
                    + Math.mulDiv(minConsensusLayerGainPerBlockPPT * reportSize, baselineGrossCLBalance, _PPT_DENOMINATOR);

                if (newGrossCLBalance < lowerBound) {
                    return ("Consensus layer change below min gain or max loss", newGrossCLBalance, lowerBound);
                }
            }
            {
                uint256 upperBound = baselineGrossCLBalance
                    + Math.mulDiv(maxConsensusLayerGainPerBlockPPT * reportSize, baselineGrossCLBalance, _PPT_DENOMINATOR);

                if (newGrossCLBalance > upperBound) {
                    return ("Consensus layer change above max gain", newGrossCLBalance, upperBound);
                }
            }
        }

        return ("", 0, 0);
    }

    function _pushRecord(OracleRecord memory record, address bridge, address l2Strategy, uint256 sourceChainId, uint256 destChainId) internal {
        emit OracleRecordAdded(_records.length, record);
        _records.push(record);

        IReturnsAggregator(getLocator().returnsAggregator()).processReturns({
            rewardAmount: record.windowWithdrawnRewardAmount,
            principalAmount: record.windowWithdrawnPrincipalAmount,
            shouldIncludeELRewards: true,
            bridge: bridge,
            l2Strategy: l2Strategy,
            sourceChainId: sourceChainId,
            destChainId: destChainId
        });
    }

    function acceptPendingUpdate(address bridge, address l2Strategy, uint256 sourceChainId, uint256 destChainId) external onlyRole(ORACLE_PENDING_UPDATE_RESOLVER_ROLE) {
        if (!hasPendingUpdate) {
            revert NoUpdatePending();
        }

        _pushRecord(_pendingUpdate, bridge, l2Strategy, sourceChainId, destChainId);
        _resetPending();
    }

    function rejectPendingUpdate() external onlyRole(ORACLE_PENDING_UPDATE_RESOLVER_ROLE) {
        if (!hasPendingUpdate) {
            revert NoUpdatePending();
        }

        emit OraclePendingUpdateRejected(_pendingUpdate);
        _resetPending();
    }

    function latestRecord() public view returns (OracleRecord memory) {
        return _records[_records.length - 1];
    }

    function pendingUpdate() external view returns (OracleRecord memory) {
        if (!hasPendingUpdate) {
            revert NoUpdatePending();
        }
        return _pendingUpdate;
    }

    function recordAt(uint256 idx) external view returns (OracleRecord memory) {
        return _records[idx];
    }

    function numRecords() external view returns (uint256) {
        return _records.length;
    }

    function _resetPending() internal {
        delete _pendingUpdate;
        hasPendingUpdate = false;
    }

    function setFinalizationBlockNumberDelta(uint256 finalizationBlockNumberDelta_)
        external
        onlyRole(ORACLE_MANAGER_ROLE)
    {
        if (
            finalizationBlockNumberDelta_ == 0
                || finalizationBlockNumberDelta_ > _FINALIZATION_BLOCK_NUMBER_DELTA_UPPER_BOUND
        ) {
            revert InvalidConfiguration();
        }

        finalizationBlockNumberDelta = finalizationBlockNumberDelta_;
        emit ProtocolConfigChanged(
            this.setFinalizationBlockNumberDelta.selector,
            "setFinalizationBlockNumberDelta(uint256)",
            abi.encode(finalizationBlockNumberDelta_)
        );
    }

    function setOracleUpdater(address newUpdater) external onlyRole(ORACLE_MANAGER_ROLE) notZeroAddress(newUpdater) {
        oracleUpdater = newUpdater;
        emit ProtocolConfigChanged(this.setOracleUpdater.selector, "setOracleUpdater(address)", abi.encode(newUpdater));
    }

    function setMinDepositPerValidator(uint256 minDepositPerValidator_) external onlyRole(ORACLE_MANAGER_ROLE) {
        minDepositPerValidator = minDepositPerValidator_;
        emit ProtocolConfigChanged(
            this.setMinDepositPerValidator.selector,
            "setMinDepositPerValidator(uint256)",
            abi.encode(minDepositPerValidator_)
        );
    }

    function setMaxDepositPerValidator(uint256 maxDepositPerValidator_) external onlyRole(ORACLE_MANAGER_ROLE) {
        maxDepositPerValidator = maxDepositPerValidator_;
        emit ProtocolConfigChanged(
            this.setMaxDepositPerValidator.selector,
            "setMaxDepositPerValidator(uint256)",
            abi.encode(maxDepositPerValidator)
        );
    }

    function setMinConsensusLayerGainPerBlockPPT(uint40 minConsensusLayerGainPerBlockPPT_)
        external
        onlyRole(ORACLE_MANAGER_ROLE)
        onlyFractionLeqOne(minConsensusLayerGainPerBlockPPT_, _PPT_DENOMINATOR)
    {
        minConsensusLayerGainPerBlockPPT = minConsensusLayerGainPerBlockPPT_;
        emit ProtocolConfigChanged(
            this.setMinConsensusLayerGainPerBlockPPT.selector,
            "setMinConsensusLayerGainPerBlockPPT(uint40)",
            abi.encode(minConsensusLayerGainPerBlockPPT_)
        );
    }

    function setMaxConsensusLayerGainPerBlockPPT(uint40 maxConsensusLayerGainPerBlockPPT_)
        external
        onlyRole(ORACLE_MANAGER_ROLE)
        onlyFractionLeqOne(maxConsensusLayerGainPerBlockPPT_, _PPT_DENOMINATOR)
    {
        maxConsensusLayerGainPerBlockPPT = maxConsensusLayerGainPerBlockPPT_;
        emit ProtocolConfigChanged(
            this.setMaxConsensusLayerGainPerBlockPPT.selector,
            "setMaxConsensusLayerGainPerBlockPPT(uint40)",
            abi.encode(maxConsensusLayerGainPerBlockPPT_)
        );
    }

    function setMaxConsensusLayerLossPPM(uint24 maxConsensusLayerLossPPM_)
        external
        onlyRole(ORACLE_MANAGER_ROLE)
        onlyFractionLeqOne(maxConsensusLayerLossPPM_, _PPM_DENOMINATOR)
    {
        maxConsensusLayerLossPPM = maxConsensusLayerLossPPM_;
        emit ProtocolConfigChanged(
            this.setMaxConsensusLayerLossPPM.selector,
            "setMaxConsensusLayerLossPPM(uint24)",
            abi.encode(maxConsensusLayerLossPPM_)
        );
    }

    function setMinReportSizeBlocks(uint16 minReportSizeBlocks_) external onlyRole(ORACLE_MANAGER_ROLE) {
        minReportSizeBlocks = minReportSizeBlocks_;
        emit ProtocolConfigChanged(
            this.setMinReportSizeBlocks.selector, "setMinReportSizeBlocks(uint16)", abi.encode(minReportSizeBlocks_)
        );
    }

    modifier onlyFractionLeqOne(uint256 numerator, uint256 denominator) {
        if (numerator > denominator) {
            revert InvalidConfiguration();
        }
        _;
    }
}
