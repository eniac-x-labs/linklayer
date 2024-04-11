// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


interface IUnstakeRequestsManagerWrite {
    function create(address requester, address l2Strategy, uint256 dETHLocked, uint256 ethRequested, uint256 destChainId) external;

    function claim(address l2Strategy, address bridge, uint256 sourceChainId, uint256 destChainId, uint256 gasLimit)  external returns (bool);

    function allocateETH() external payable;

    function withdrawAllocatedETHSurplus() external;
}

interface IUnstakeRequestsManagerRead {
    function requestByID(uint256 destChainId, address l2strategy) external view returns (uint256, uint256, uint256);

    function requestInfo(uint256 destChainId, address l2strategy) external view returns (bool, uint256);

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
        address indexed requester,
        address indexed strategy,
        uint256 dETHLocked,
        uint256 ethRequested,
        uint256 cumulativeETHRequested,
        uint256 blockNumber,
        uint256 destChainId
    );

    event UnstakeRequestClaimed(
        address indexed l2strategy,
        uint256 ethRequested,
        uint256 dETHLocked,
        uint256 indexed destChainId,
        uint256 indexed csBlockNumber
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
