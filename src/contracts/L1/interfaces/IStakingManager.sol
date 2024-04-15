// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStakingManagerInitiationRead {
    function totalDepositedInValidators() external view returns (uint256);

    function numInitiatedValidators() external view returns (uint256);

    function initializationBlockNumber() external view returns (uint256);
}

interface IStakingManagerReturnsWrite {
    function receiveReturns() external payable;
    function receiveFromUnstakeRequestsManager() external payable;
}

interface IStakingManager is IStakingManagerInitiationRead, IStakingManagerReturnsWrite {
    error DoesNotReceiveETH();
    error InvalidConfiguration();
    error MaximumValidatorDepositExceeded();
    error MaximumDETHSupplyExceeded();
    error MinimumStakeBoundNotSatisfied();
    error MinimumDepositAmountNotSatisfied();
    error MinimumUnstakeBoundNotSatisfied();
    error MinimumValidatorDepositNotSatisfied();
    error NotEnoughDepositETH();
    error NotEnoughUnallocatedETH();
    error NotReturnsAggregator();
    error NotUnstakeRequestsManager();
    error NotDappLinkBridge();
    error Paused();
    // error ZeroAddress();
    error PreviouslyUsedValidator();
    error InvalidDepositRoot(bytes32);
    error UnstakeBelowMinimudETHAmount(uint256 ethAmount, uint256 expectedMinimum);

    error InvalidWithdrawalCredentialsWrongLength(uint256);
    error InvalidWithdrawalCredentialsNotETH1(bytes12);
    error InvalidWithdrawalCredentialsWrongAddress(address);


    event Staked(address indexed staker, uint256 ethAmount, uint256 dETHAmount);
    event UnstakeLaveAmount(address indexed staker, uint256 dETHLocked);
    event UnstakeRequested(address indexed staker, address indexed l2Strategy, uint256 ethAmount, uint256 dETHLocked, uint256 destChainId, uint256 unStakeMessageNonce);
    event UnstakeRequestClaimed(address indexed staker, address[] indexed l2Strategys, address indexed bridge, uint256 sourceChainId, uint256 destChainId);
    event ValidatorInitiated(bytes32 indexed id, uint256 indexed operatorID, bytes pubkey, uint256 amountDeposited);
    event AllocatedETHToUnstakeRequestsManager(uint256 amount);
    event AllocatedETHToDeposits(uint256 amount);
    event ReturnsReceived(uint256 amount);
}
