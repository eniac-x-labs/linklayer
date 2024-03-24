// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import { AccessControlEnumerableUpgradeable } from "@openzeppelin-upgrades/contracts/access/extensions/AccessControlEnumerableUpgradeable.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20Upgradeable } from "@openzeppelin-upgrades/contracts/token/ERC20/ERC20Upgradeable.sol";

import {ProtocolEvents} from "../interfaces/ProtocolEvents.sol";
import {IDETH} from "../interfaces/IDETH.sol";
import {IOracleReadRecord} from "../interfaces/IOracleManager.sol";
import {
    IUnstakeRequestsManager,
    IUnstakeRequestsManagerWrite,
    IUnstakeRequestsManagerRead,
    UnstakeRequest
} from "../interfaces/IUnstakeRequestsManager.sol";
import {IStakingManagerReturnsWrite} from "../interfaces/IStakingManager.sol";
import "../../libraries/SafeCall.sol";


contract UnstakeRequestsManager is
    Initializable,
    AccessControlEnumerableUpgradeable,
    IUnstakeRequestsManager,
    ProtocolEvents
{
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    bytes32 public constant REQUEST_CANCELLER_ROLE = keccak256("REQUEST_CANCELLER_ROLE");

    IStakingManagerReturnsWrite public stakingContract;

    IOracleReadRecord public oracle;
    
    uint256 public allocatedETHForClaims;

    uint256 public totalClaimed;
    
    uint256 public numberOfBlocksToFinalize;
    
    IDETH public dETH;
    
    uint128 public latestCumulativeETHRequested;
    
    UnstakeRequest[] internal _unstakeRequests;

    struct Init {
        address admin;
        address manager;
        address requestCanceller;
        IDETH dETH;
        IStakingManagerReturnsWrite stakingContract;
        IOracleReadRecord oracle;
        uint256 numberOfBlocksToFinalize;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(Init memory init) external initializer {
        __AccessControlEnumerable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, init.admin);
        numberOfBlocksToFinalize = init.numberOfBlocksToFinalize;
        stakingContract = init.stakingContract;
        oracle = init.oracle;
        dETH = init.dETH;

        _grantRole(MANAGER_ROLE, init.manager);
        _grantRole(REQUEST_CANCELLER_ROLE, init.requestCanceller);
    }
    
    function create(address requester, uint128 dETHLocked, uint128 ethRequested)
        external
        onlyStakingContract
        returns (uint256)
    {
        uint128 currentCumulativeETHRequested = latestCumulativeETHRequested + ethRequested;
        uint256 requestID = _unstakeRequests.length;
        UnstakeRequest memory unstakeRequest = UnstakeRequest({
            id: uint128(requestID),
            requester: requester,
            dETHLocked: dETHLocked,
            ethRequested: ethRequested,
            cumulativeETHRequested: currentCumulativeETHRequested,
            blockNumber: uint64(block.number)
        });
        _unstakeRequests.push(unstakeRequest);

        latestCumulativeETHRequested = currentCumulativeETHRequested;
        emit UnstakeRequestCreated(
            requestID, requester, dETHLocked, ethRequested, currentCumulativeETHRequested, block.number
        );
        return requestID;
    }

    function claim(uint256 requestID, address requester, address bridge, uint256 sourceChainId, uint256 destChainId, uint256 gasLimit) external onlyStakingContract returns (bool) {
        UnstakeRequest memory request = _unstakeRequests[requestID];

        if (request.requester == address(0)) {
            revert AlreadyClaimed();
        }

        if (requester != request.requester) {
            revert NotRequester();
        }

        if (!_isFinalized(request)) {
            revert NotFinalized();
        }

        if (request.cumulativeETHRequested > allocatedETHForClaims) {
            revert NotEnoughFunds(request.cumulativeETHRequested, allocatedETHForClaims);
        }

        delete _unstakeRequests[requestID];
        totalClaimed += request.ethRequested;

        emit UnstakeRequestClaimed({
            id: requestID,
            requester: requester,
            dETHLocked: request.dETHLocked,
            ethRequested: request.ethRequested,
            cumulativeETHRequested: request.cumulativeETHRequested,
            blockNumber: request.blockNumber
        });
        dETH.burn(request.dETHLocked);
        bool success = SafeCall.callWithMinGas(
            bridge,
            gasLimit,
            request.ethRequested,
            abi.encodeWithSignature("BridgeInitiateETH(uint256,uint256,to,value)", sourceChainId, destChainId, bridge, request.ethRequested)
        );
        return success;
    }


    function cancelUnfinalizedRequests(uint256 maxCancel) external onlyRole(REQUEST_CANCELLER_ROLE) returns (bool) {
        uint256 length = _unstakeRequests.length;
        if (length == 0) {
            return false;
        }

        if (length < maxCancel) {
            maxCancel = length;
        }

 
        UnstakeRequest[] memory requests = new UnstakeRequest[](maxCancel);

        uint256 numCancelled = 0;
        uint128 amountETHCancelled = 0;
        while (numCancelled < maxCancel) {
            UnstakeRequest memory request = _unstakeRequests[_unstakeRequests.length - 1];

            if (_isFinalized(request)) {
                break;
            }

            _unstakeRequests.pop();
            requests[numCancelled] = request;
            ++numCancelled;
            amountETHCancelled += request.ethRequested;

            emit UnstakeRequestCancelled(
                request.id,
                request.requester,
                request.dETHLocked,
                request.ethRequested,
                request.cumulativeETHRequested,
                request.blockNumber
            );
        }

        if (amountETHCancelled > 0) {
            latestCumulativeETHRequested -= amountETHCancelled;
        }

        bool hasMore;
        uint256 remainingRequestsLength = _unstakeRequests.length;
        if (remainingRequestsLength == 0) {
            hasMore = false;
        } else {
            UnstakeRequest memory latestRemainingRequest = _unstakeRequests[remainingRequestsLength - 1];
            hasMore = !_isFinalized(latestRemainingRequest);
        }

        for (uint256 i = 0; i < numCancelled; i++) {
            SafeERC20.safeTransfer(dETH, requests[i].requester, requests[i].dETHLocked);
        }

        return hasMore;
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
        stakingContract.receiveFromUnstakeRequestsManager{value: toSend}();
    }

    function nextRequestId() external view returns (uint256) {
        return _unstakeRequests.length;
    }

    function requestByID(uint256 requestID) external view returns (UnstakeRequest memory) {
        return _unstakeRequests[requestID];
    }

    function requestInfo(uint256 requestID) external view returns (bool, uint256) {
        UnstakeRequest memory request = _unstakeRequests[requestID];

        bool isFinalized = _isFinalized(request);
        uint256 claimableAmount = 0;
        
        uint256 allocatedEthRequired = request.cumulativeETHRequested - request.ethRequested;
        if (allocatedEthRequired < allocatedETHForClaims) {
            claimableAmount = Math.min(allocatedETHForClaims - allocatedEthRequired, request.ethRequested);
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
    
    function _isFinalized(UnstakeRequest memory request) internal view returns (bool) {
        return (request.blockNumber + numberOfBlocksToFinalize) <= oracle.latestRecord().updateEndBlock;
    }

    modifier onlyStakingContract() {
        if (msg.sender != address(stakingContract)) {
            revert NotStakingManagerContract();
        }
        _;
    }
    
    receive() external payable {
        revert DoesNotReceiveETH();
    }

    fallback() external payable {
        revert DoesNotReceiveETH();
    }
}
