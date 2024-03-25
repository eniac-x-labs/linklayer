// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { StakingManager } from "@/contracts/L1/core/StakingManager.sol";

struct UnstakeRequest {
    uint64 blockNumber;
    address requester;
    uint128 id;
    uint256 dETHLocked;
    uint256 ethRequested;
    uint256 cumulativeETHRequested;
}

interface IUnstakeRequestsManagerWrite {
    function create(address requester, uint256 dETHLocked, uint256 ethRequested) external returns (uint256);

    function claim(uint256 requestID, address requester, address bridge, uint256 sourceChainId, uint256 destChainId, uint256 gasLimit) external returns (bool);

    function cancelUnfinalizedRequests(uint256 maxCancel) external returns (bool);

    function allocateETH() external payable;

    function withdrawAllocatedETHSurplus() external;
}

interface IUnstakeRequestsManagerRead {
    function requestByID(uint256 requestID) external view returns (UnstakeRequest memory);

    function requestInfo(uint256 requestID) external view returns (bool, uint256);

    function allocatedETHSurplus() external view returns (uint256);

    function allocatedETHDeficit() external view returns (uint256);

    function balance() external view returns (uint256);
}

interface IUnstakeRequestsManager is IUnstakeRequestsManagerRead, IUnstakeRequestsManagerWrite {
    error AlreadyClaimed();
    error DoesNotReceiveETH();
    error NotEnoughFunds(uint256 cumulativeETHOnRequest, uint256 allocatedETHForClaims);
    error NotFinalized();
    error NotRequester();
    error NotStakingManagerContract();

    event UnstakeRequestCreated(
        uint256 indexed id,
        address indexed requester,
        uint256 dETHLocked,
        uint256 ethRequested,
        uint256 cumulativeETHRequested,
        uint256 blockNumber
    );

    event UnstakeRequestClaimed(
        uint256 indexed id,
        address indexed requester,
        uint256 dETHLocked,
        uint256 ethRequested,
        uint256 cumulativeETHRequested,
        uint256 blockNumber
    );

    event UnstakeRequestCancelled(
        uint256 indexed id,
        address indexed requester,
        uint256 dETHLocked,
        uint256 ethRequested,
        uint256 cumulativeETHRequested,
        uint256 blockNumber
    );
}
