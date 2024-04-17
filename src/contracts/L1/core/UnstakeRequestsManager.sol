// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import {L1Base} from "@/contracts/L1/core/L1Base.sol";
import {IDETH} from "../interfaces/IDETH.sol";
import {IOracleReadRecord} from "../interfaces/IOracleManager.sol";
import {
    IUnstakeRequestsManager,
    IUnstakeRequestsManagerWrite,
    IUnstakeRequestsManagerRead
} from "../interfaces/IUnstakeRequestsManager.sol";
import {IStakingManagerReturnsWrite} from "../interfaces/IStakingManager.sol";
import "../../libraries/SafeCall.sol";


contract UnstakeRequestsManager is
    L1Base,
    IUnstakeRequestsManager
{
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    bytes32 public constant REQUEST_CANCELLER_ROLE = keccak256("REQUEST_CANCELLER_ROLE");

    uint256 public allocatedETHForClaims;

    uint256 public totalClaimed;
    
    uint256 public numberOfBlocksToFinalize;
    
    uint256 public latestCumulativeETHRequested;
    
    mapping(uint256 => mapping(address => uint256)) public l2ChainStrategyAmount;
    mapping(uint256 => mapping(address => uint256)) public dEthLockedAmount;
    mapping(uint256 => mapping(address => uint256)) public l2ChainStrategyBlockNumber;
    mapping(uint256 => mapping(address => uint256)) public currentRequestedCumulativeETH;


    struct Init {
        address admin;
        address manager;
        address requestCanceller;
        uint256 numberOfBlocksToFinalize;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(Init memory init) external initializer {
        __L1Base_init(init.admin);
        _grantRole(MANAGER_ROLE, init.manager);
        _grantRole(REQUEST_CANCELLER_ROLE, init.requestCanceller);

        numberOfBlocksToFinalize = init.numberOfBlocksToFinalize;
    }
    
    function create(address requester, address l2Strategy, uint256 dETHLocked, uint256 ethRequested, uint256 destChainId)
        external
        onlyStakingContract
    {
        uint256 currentCumulativeETHRequested = latestCumulativeETHRequested + ethRequested;

        l2ChainStrategyAmount[destChainId][l2Strategy] += ethRequested;
        dEthLockedAmount[destChainId][l2Strategy] += dETHLocked;
        l2ChainStrategyBlockNumber[destChainId][l2Strategy] = block.number;
        currentRequestedCumulativeETH[destChainId][l2Strategy] = currentCumulativeETHRequested;

        latestCumulativeETHRequested = currentCumulativeETHRequested;

        emit UnstakeRequestCreated(
            requester, l2Strategy, dETHLocked, ethRequested, currentCumulativeETHRequested, block.number, destChainId
        );
    }

    function claim(requestsInfo[] memory requests, uint256 sourceChainId, uint256 destChainId, uint256 gasLimit) external onlyStakingContract {
        if (requests.length == 0) {
            revert NoRequests();
        }

        for (uint256 i = 0; i < requests.length; i++) {
            address requester = requests[i].requestAddress;
            uint256 unStakeMessageNonce  = requests[i].unStakeMessageNonce;
            _claim(requester, unStakeMessageNonce, sourceChainId, destChainId, gasLimit);
        }
    }

    function _claim(address requester, uint256 unStakeMessageNonce, uint256 sourceChainId, uint256 destChainId, uint256 gasLimit) private {

        uint256 csBlockNumber = l2ChainStrategyBlockNumber[destChainId][requester];
        uint256 ethRequested = l2ChainStrategyAmount[destChainId][requester];
        uint256 dETHLocked = dEthLockedAmount[destChainId][requester];

        delete l2ChainStrategyAmount[destChainId][requester];
        delete dEthLockedAmount[destChainId][requester];
        delete l2ChainStrategyBlockNumber[destChainId][requester];

        // Todo: Will addresses it in the future
        // if (!_isFinalized(csBlockNumber)) {
        //     revert NotFinalized();
        // }

        emit UnstakeRequestClaimed({
            l2strategy: requester,
            ethRequested: ethRequested,
            dETHLocked: dETHLocked,
            destChainId: destChainId,
            csBlockNumber: csBlockNumber,
            bridgeAddress: getLocator().dapplinkBridge(),
            unStakeMessageNonce: unStakeMessageNonce
        });
        getDETH().burn(dETHLocked);
        bool success = SafeCall.callWithMinGas(
            getLocator().dapplinkBridge(),
            gasLimit,
            ethRequested,
            abi.encodeWithSignature("BridgeInitiateETH(uint256,uint256,address)", sourceChainId, destChainId, requester)
        );
        if (!success) {
            revert BridgeInitiateETHFailed();
        }
    }

    function allocateETH() external payable onlyStakingContract {
        allocatedETHForClaims += msg.value;
    }

    function withdrawAllocatedETHSurplus() external onlyStakingContract {
        uint256 toSend = allocatedETHSurplus();
        if (toSend == 0) {
            return;
        }
        allocatedETHForClaims -= toSend;
        IStakingManagerReturnsWrite(getLocator().stakingManager()).receiveFromUnstakeRequestsManager{value: toSend}();
    }

    function requestByID(uint256 destChainId, address l2Strategy) external view returns (uint256, uint256, uint256){
        uint256 csBlockNumber = l2ChainStrategyBlockNumber[destChainId][l2Strategy];
        uint256 ethRequested = l2ChainStrategyAmount[destChainId][l2Strategy];
        uint256 dETHLocked = dEthLockedAmount[destChainId][l2Strategy];
        return(ethRequested, dETHLocked, csBlockNumber);
    }

    function requestInfo(uint256 destChainId, address l2Strategy) external view returns (bool, uint256) {
        uint256 csBlockNumber = l2ChainStrategyBlockNumber[destChainId][l2Strategy];
        uint256 ethRequested = l2ChainStrategyAmount[destChainId][l2Strategy];
        uint256 dETHLocked = dEthLockedAmount[destChainId][l2Strategy];
        uint256 cumulativeETHRequested = currentRequestedCumulativeETH[destChainId][l2Strategy];

        bool isFinalized = _isFinalized(csBlockNumber);
        uint256 claimableAmount = 0;
        
        uint256 allocatedEthRequired = cumulativeETHRequested - ethRequested;
        if (allocatedEthRequired < allocatedETHForClaims) {
            claimableAmount = Math.min(allocatedETHForClaims - allocatedEthRequired,  ethRequested);
        }
        return (isFinalized, claimableAmount);
    }
    
    function allocatedETHSurplus() public view returns (uint256) {
        if (allocatedETHForClaims > latestCumulativeETHRequested) {
            return allocatedETHForClaims - latestCumulativeETHRequested;
        }
        return 0;
    }
    
    function allocatedETHDeficit() external view returns (uint256) {
        if (latestCumulativeETHRequested > allocatedETHForClaims) {
            return latestCumulativeETHRequested - allocatedETHForClaims;
        }
        return 0;
    }
    
    function balance() external view returns (uint256) {
        if (allocatedETHForClaims > totalClaimed) {
            return allocatedETHForClaims - totalClaimed;
        }
        return 0;
    }
    
    function setNumberOfBlocksToFinalize(uint256 numberOfBlocksToFinalize_) external onlyRole(MANAGER_ROLE) {
        numberOfBlocksToFinalize = numberOfBlocksToFinalize_;
        emit ProtocolConfigChanged(
            this.setNumberOfBlocksToFinalize.selector,
            "setNumberOfBlocksToFinalize(uint256)",
            abi.encode(numberOfBlocksToFinalize_)
        );
    }
    
    function _isFinalized(uint256 blockNumber) internal view returns (bool) {
        return (blockNumber + numberOfBlocksToFinalize) <= IOracleReadRecord(getLocator().oracleManager()).latestRecord().updateEndBlock;
    }

    modifier onlyStakingContract() {
        if (msg.sender != getLocator().stakingManager()) {
            revert NotStakingManagerContract();
        }
        _;
    }
    // receive() external payable {
    //     revert DoesNotReceiveETH();
    // }

    // fallback() external payable {
    //     revert DoesNotReceiveETH();
    // }
}
