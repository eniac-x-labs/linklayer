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
    IUnstakeRequestsManagerRead
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
    
    uint256 public latestCumulativeETHRequested;
    
    mapping(uint256 => mapping(address => uint256)) public l2ChainStrategyAmount;
    mapping(uint256 => mapping(address => uint256)) public dEthLockedAmount;
    mapping(uint256 => mapping(address => uint256)) public l2ChainStrategyBlockNumber;
    mapping(uint256 => mapping(address => uint256)) public currentRequestedCumulativeETH;


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

    function claim(address l2Strategy, address bridge, uint256 sourceChainId, uint256 destChainId, uint256 gasLimit) external onlyStakingContract returns (bool) {

        uint256 csBlockNumber = l2ChainStrategyBlockNumber[destChainId][l2Strategy];
        uint256 ethRequested = l2ChainStrategyAmount[destChainId][l2Strategy];
        uint256 dETHLocked = dEthLockedAmount[destChainId][l2Strategy];

        delete l2ChainStrategyAmount[destChainId][l2Strategy];
        delete dEthLockedAmount[destChainId][l2Strategy];
        delete l2ChainStrategyBlockNumber[destChainId][l2Strategy];

         if (!_isFinalized(csBlockNumber)) {
            revert NotFinalized();
        }

        emit UnstakeRequestClaimed({
            l2strategy: l2Strategy,
            ethRequested: ethRequested,
            dETHLocked: dETHLocked,
            destChainId: destChainId,
            csBlockNumber: csBlockNumber
        });
        dETH.burn(dETHLocked);
        bool success = SafeCall.callWithMinGas(
            bridge,
            gasLimit,
            ethRequested,
            abi.encodeWithSignature("BridgeInitiateETH(uint256,uint256,to,value)", sourceChainId, destChainId, bridge, ethRequested)
        );
        return success;
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
        return (blockNumber + numberOfBlocksToFinalize) <= oracle.latestRecord().updateEndBlock;
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
