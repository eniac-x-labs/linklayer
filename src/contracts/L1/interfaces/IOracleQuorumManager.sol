// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OracleRecord, IOracleManager} from "./IOracleManager.sol";


interface IOracleQuorumManager {
    error InvalidReporter();
    error AlreadyReporter();
    error RelativeThresholdExceedsOne();

    event ReportQuorumReached(uint64 indexed block);
    event ReportReceived(uint64 indexed block, address indexed reporter, bytes32 indexed recordHash, OracleRecord record);
    event OracleRecordReceivedError(bytes reason);
}
