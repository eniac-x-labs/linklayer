// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IDETH } from "../interfaces/IDETH.sol";
import { IOracleReadRecord, OracleRecord } from "../interfaces/IOracleManager.sol";
import { StakingManagerStorage } from "./StakingManagerStorage.sol";
import {L1Base} from "@/contracts/L1/core/L1Base.sol";
import { IUnstakeRequestsManagerWrite } from "../interfaces/IUnstakeRequestsManager.sol";


contract StakingManager is L1Base, StakingManagerStorage{
    mapping(bytes pubkey => bool exists) public usedValidators;

    uint256 public totalDepositedInValidators;

    uint256 public numInitiatedValidators;

    uint256 public unallocatedETH;

    uint256 public allocatedETHForDeposits;

    uint256 public minimumUnstakeBound;

    uint16 public exchangeAdjustmentRate;

    uint16 internal constant _BASIS_POINTS_DENOMINATOR = 10_000;

    uint16 internal constant _MAX_EXCHANGE_ADJUSTMENT_RATE = _BASIS_POINTS_DENOMINATOR / 10; // 10%

    uint256 public minimumDepositAmount;

    uint256 public maximumDepositAmount;

    address public withdrawalWallet;

    bool public isStakingAllowlist;

    uint256 public initializationBlockNumber;

    uint256 public maximumDETHSupply;

    uint256 public unStakeMessageNonce;

    struct Init {
        address admin;
        address manager;
        address allocatorService;
        address initiatorService;
        address withdrawalWallet;
    }


    constructor() {
        _disableInitializers();
    }



    function initialize(Init memory init) external initializer {
        __L1Base_init(init.admin);
        _grantRole(STAKING_MANAGER_ROLE, init.manager);
        _grantRole(ALLOCATOR_SERVICE_ROLE, init.allocatorService);
        _grantRole(INITIATOR_SERVICE_ROLE, init.initiatorService);

        withdrawalWallet = init.withdrawalWallet;

        minimumUnstakeBound = 0.01 ether;
        minimumDepositAmount = 32 ether;
        isStakingAllowlist = true;
        initializationBlockNumber = block.number;

        maximumDETHSupply = 1024 ether;
        unStakeMessageNonce = 0;
    }

    //function withdraw()external{
     //  msg.sender.call{value: address(this).balance}("");
    //}
    function stake(uint256 stakeAmount,IDETH.BatchMint[] calldata batchMints) external onlyDappLinkBridge payable {
        if (getL1Pauser().isStakingPaused()) {
            revert Paused();
        }

        if (msg.value < minimumDepositAmount || stakeAmount < minimumDepositAmount) {
            revert MinimumDepositAmountNotSatisfied();
        }

        uint256 dETHMintAmount = ethToDETH(stakeAmount);
        if (dETHMintAmount + getDETH().totalSupply() > maximumDETHSupply) {
            revert MaximumDETHSupplyExceeded();
        }

        unallocatedETH += stakeAmount;

        getDETH().batchMint(batchMints);

        emit Staked(getLocator().dapplinkBridge(), stakeAmount, dETHMintAmount);
    }

    function unstakeRequest(uint128 dethAmount, uint128 minETHAmount, address l2Strategy, uint256 destChainId) external  {
        _unstakeRequest(dethAmount, minETHAmount, l2Strategy, destChainId);
    }

    function _unstakeRequest(uint128 dethAmount, uint128 minETHAmount, address l2Strategy, uint256 destChainId) internal {
        if (getL1Pauser().isUnstakeRequestsAndClaimsPaused()) {
            revert Paused();
        }

        if (dethAmount < minimumUnstakeBound) {
            revert MinimumUnstakeBoundNotSatisfied();
        }

        uint128 ethAmount = uint128(dETHToETH(dethAmount));
        if (ethAmount < minETHAmount) {
            revert UnstakeBelowMinimudETHAmount(ethAmount, minETHAmount);
        }

        getUnstakeRequestsManager().create({requester: msg.sender, l2Strategy: l2Strategy, dETHLocked: dethAmount, ethRequested: ethAmount, destChainId: destChainId});

        unStakeMessageNonce++;

        emit UnstakeRequested({staker: msg.sender, l2Strategy: l2Strategy, ethAmount: ethAmount, dETHLocked: dethAmount, destChainId: destChainId, unStakeMessageNonce: unStakeMessageNonce});

        SafeERC20.safeTransferFrom(getDETH(), msg.sender, getLocator().unStakingRequestsManager(), dethAmount);
    }
    
    function claimUnstakeRequest(IUnstakeRequestsManagerWrite.requestsInfo[] memory requests, uint256 sourceChainId, uint256 destChainId, uint256 gasLimit) external onlyRelayer {
        if (getL1Pauser().isUnstakeRequestsAndClaimsPaused()) {
            revert Paused();
        }
        getUnstakeRequestsManager().claim(requests, sourceChainId, destChainId, gasLimit);
    }
    
    function unstakeRequestInfo(uint256 destChainId, address l2strategy) external view  returns (bool, uint256) {
        return getUnstakeRequestsManager().requestInfo(destChainId, l2strategy);
    }
    
    function reclaimAllocatedETHSurplus() external onlyRole(STAKING_MANAGER_ROLE) {
        getUnstakeRequestsManager().withdrawAllocatedETHSurplus();
    }
    
    function allocateETH(uint256 allocateToUnstakeRequestsManager, uint256 allocateToDeposits)
        external
        onlyRole(ALLOCATOR_SERVICE_ROLE)
    {
        if (getL1Pauser().isAllocateETHPaused()) {
            revert Paused();
        }

        if (allocateToUnstakeRequestsManager + allocateToDeposits > unallocatedETH) {
            revert NotEnoughUnallocatedETH();
        }

        unallocatedETH -= allocateToUnstakeRequestsManager + allocateToDeposits;

        if (allocateToDeposits > 0) {
            allocatedETHForDeposits += allocateToDeposits;
            emit AllocatedETHToDeposits(allocateToDeposits);
        }

        if (allocateToUnstakeRequestsManager > 0) {
            emit AllocatedETHToUnstakeRequestsManager(allocateToUnstakeRequestsManager);
            getUnstakeRequestsManager().allocateETH{value: allocateToUnstakeRequestsManager}();
        }
    }

    function initiateValidatorsWithDeposits(ValidatorParams[] calldata validators, bytes32 expectedDepositRoot)
        external
        onlyRole(INITIATOR_SERVICE_ROLE)
    {
        if (getL1Pauser().isInitiateValidatorsPaused()) {
            revert Paused();
        }
        if (validators.length == 0) {
            return;
        }

        bytes32 actualRoot = getDepositContract().get_deposit_root();
        if (expectedDepositRoot != actualRoot) {
            revert InvalidDepositRoot(actualRoot);
        }

        uint256 amountDeposited = 0;
        for (uint256 i = 0; i < validators.length; ++i) {
            ValidatorParams calldata validator = validators[i];

            if (usedValidators[validator.pubkey]) {
                revert PreviouslyUsedValidator();
            }

            if (validator.depositAmount != minimumDepositAmount) {
                revert MinimumValidatorDepositNotSatisfied();
            }


            _requireProtocolWithdrawalAccount(validator.withdrawalCredentials);

            usedValidators[validator.pubkey] = true;
            amountDeposited += validator.depositAmount;

            emit ValidatorInitiated({
                id: keccak256(validator.pubkey),
                operatorID: validator.operatorID,
                pubkey: validator.pubkey,
                amountDeposited: validator.depositAmount
            });
        }

        if (amountDeposited > allocatedETHForDeposits) {
            revert NotEnoughDepositETH();
        }

        allocatedETHForDeposits -= amountDeposited;
        totalDepositedInValidators += amountDeposited;
        numInitiatedValidators += validators.length;

        for (uint256 i = 0; i < validators.length; ++i) {
            ValidatorParams calldata validator = validators[i];
            getDepositContract().deposit{value: validator.depositAmount}({
                pubkey: validator.pubkey,
                withdrawal_credentials: validator.withdrawalCredentials,
                signature: validator.signature,
                deposit_data_root: validator.depositDataRoot
            });
        }
    }
    
    function receiveFromUnstakeRequestsManager() external payable onlyUnstakeRequestsManager {
        unallocatedETH += msg.value;
    }

    function topUp() external payable onlyRole(TOP_UP_ROLE) {
        unallocatedETH += msg.value;
    }
    
    function ethToDETH(uint256 ethAmount) public returns (uint256) {
        if (getDETH().totalSupply() == 0) {
            return ethAmount;
        }
        return Math.mulDiv(
            ethAmount,
            getDETH().totalSupply() * uint256(_BASIS_POINTS_DENOMINATOR - exchangeAdjustmentRate),
            totalControlled() * uint256(_BASIS_POINTS_DENOMINATOR)
        );
    }
    
    function dETHToETH(uint256 dETHAmount) public returns (uint256) {
        if (getDETH().totalSupply() == 0) {
            return dETHAmount;
        }
        return Math.mulDiv(dETHAmount, totalControlled(), getDETH().totalSupply());
    }
    
    function totalControlled() public returns (uint256) {
        OracleRecord memory record = IOracleReadRecord(getLocator().oracleManager()).latestRecord();
        uint256 total = 0;
        total += unallocatedETH;
        total += allocatedETHForDeposits;
        
        total += totalDepositedInValidators - record.cumulativeProcessedDepositAmount;
        total += record.currentTotalValidatorBalance;
        total += getUnstakeRequestsManager().balance();
        return total;
    }
    
    function _requireProtocolWithdrawalAccount(bytes calldata withdrawalCredentials) internal view {
        if (withdrawalCredentials.length != 32) {
            revert InvalidWithdrawalCredentialsWrongLength(withdrawalCredentials.length);
        }

        bytes12 prefixAndPadding = bytes12(withdrawalCredentials[:12]);
        if (prefixAndPadding != 0x010000000000000000000000) {
            revert InvalidWithdrawalCredentialsNotETH1(prefixAndPadding);
        }

        address addr = address(bytes20(withdrawalCredentials[12:32]));
        if (addr != withdrawalWallet) {
            revert InvalidWithdrawalCredentialsWrongAddress(addr);
        }
    }
    
    function receiveReturns() external payable onlyReturnsAggregator {
        emit ReturnsReceived(msg.value);
        unallocatedETH += msg.value;
    }

    modifier onlyReturnsAggregator() {
        if (msg.sender != getLocator().returnsAggregator()) {
            revert NotReturnsAggregator();
        }
        _;
    }

    modifier onlyUnstakeRequestsManager() {
        if (msg.sender != getLocator().unStakingRequestsManager()) {
            revert NotUnstakeRequestsManager();
        }
        _;
    }

     modifier onlyDappLinkBridge() {
        if (msg.sender != getLocator().dapplinkBridge()) {
            revert NotDappLinkBridge();
        }
        _;
    }

    function setMinimumUnstakeBound(uint256 minimumUnstakeBound_) external onlyRole(STAKING_MANAGER_ROLE) {
        minimumUnstakeBound = minimumUnstakeBound_;
        emit ProtocolConfigChanged(
            this.setMinimumUnstakeBound.selector, "setMinimumUnstakeBound(uint256)", abi.encode(minimumUnstakeBound_)
        );
    }

    function setExchangeAdjustmentRate(uint16 exchangeAdjustmentRate_) external onlyRole(STAKING_MANAGER_ROLE) {
        if (exchangeAdjustmentRate_ > _MAX_EXCHANGE_ADJUSTMENT_RATE) {
            revert InvalidConfiguration();
        }

        assert(exchangeAdjustmentRate_ <= _BASIS_POINTS_DENOMINATOR);

        exchangeAdjustmentRate = exchangeAdjustmentRate_;
        emit ProtocolConfigChanged(
            this.setExchangeAdjustmentRate.selector,
            "setExchangeAdjustmentRate(uint16)",
            abi.encode(exchangeAdjustmentRate_)
        );
    }
    
    function setMinimumDepositAmount(uint256 minimumDepositAmount_) external onlyRole(STAKING_MANAGER_ROLE) {
        minimumDepositAmount = minimumDepositAmount_;
        emit ProtocolConfigChanged(
            this.setMinimumDepositAmount.selector, "setMinimumDepositAmount(uint256)", abi.encode(minimumDepositAmount_)
        );
    }
    
    
    function setMaximumDETHSupply(uint256 maximumDETHSupply_) external onlyRole(STAKING_MANAGER_ROLE) {
        maximumDETHSupply = maximumDETHSupply_;
        emit ProtocolConfigChanged(
            this.setMaximumDETHSupply.selector, "setMaximumDETHSupply(uint256)", abi.encode(maximumDETHSupply_)
        );
    }
    
    function setWithdrawalWallet(address withdrawalWallet_)
        external
        onlyRole(STAKING_MANAGER_ROLE)
        notZeroAddress(withdrawalWallet_)
    {
        withdrawalWallet = withdrawalWallet_;
        emit ProtocolConfigChanged(
            this.setWithdrawalWallet.selector, "setWithdrawalWallet(address)", abi.encode(withdrawalWallet_)
        );
    }

    function setStakingAllowlist(bool isStakingAllowlist_) external onlyRole(STAKING_MANAGER_ROLE) {
        isStakingAllowlist = isStakingAllowlist_;
        emit ProtocolConfigChanged(
            this.setStakingAllowlist.selector, "setStakingAllowlist(bool)", abi.encode(isStakingAllowlist_)
        );
    }

    receive() external payable {
        unallocatedETH += msg.value;
        // revert DoesNotReceiveETH();
    }

    // fallback() external payable {
    //     revert DoesNotReceiveETH();
    // }
}
