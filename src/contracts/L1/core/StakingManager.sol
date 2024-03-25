// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Initializable } from "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import { AccessControlEnumerableUpgradeable } from "@openzeppelin-upgrades/contracts/access/extensions/AccessControlEnumerableUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin-upgrades/contracts/token/ERC20/ERC20Upgradeable.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { ProtocolEvents } from "../interfaces/ProtocolEvents.sol";
import { IDepositContract } from "../interfaces/IDepositContract.sol";
import { IDETH } from "../interfaces/IDETH.sol";
import { IOracleReadRecord, OracleRecord } from "../interfaces/IOracleManager.sol";
import {IL1Pauser} from "../../access/interface/IL1Pauser.sol";
import { StakingManagerStorage } from "./StakingManagerStorage.sol";
import { UnstakeRequest, IUnstakeRequestsManager } from "../interfaces/IUnstakeRequestsManager.sol";


contract StakingManager is Initializable, AccessControlEnumerableUpgradeable, StakingManagerStorage, ProtocolEvents {
    mapping(bytes pubkey => bool exists) public usedValidators;

    uint256 public totalDepositedInValidators;

    uint256 public numInitiatedValidators;

    uint256 public unallocatedETH;

    uint256 public allocatedETHForDeposits;

    uint256 public minimumStakeBound;

    uint256 public minimumUnstakeBound;

    uint16 public exchangeAdjustmentRate;

    uint16 internal constant _BASIS_POINTS_DENOMINATOR = 10_000;

    uint16 internal constant _MAX_EXCHANGE_ADJUSTMENT_RATE = _BASIS_POINTS_DENOMINATOR / 10; // 10%

    uint256 public minimumDepositAmount;

    uint256 public maximumDepositAmount;

    IDepositContract public depositContract;

    IDETH public dETH;

    IOracleReadRecord public oracle;

    IL1Pauser public pauser;

    IUnstakeRequestsManager public unstakeRequestsManager;

    address public withdrawalWallet;

    address public returnsAggregator;

    bool public isStakingAllowlist;

    uint256 public initializationBlockNumber;

    uint256 public maximumDETHSupply;

    address public dapplinkBridge;

    struct Init {
        address admin;
        address manager;
        address allocatorService;
        address initiatorService;
        address returnsAggregator;
        address withdrawalWallet;
        address dapplinkBridge;
        IDETH dETH;
        IDepositContract depositContract;
        IOracleReadRecord oracle;
        IL1Pauser pauser;
        IUnstakeRequestsManager unstakeRequestsManager;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(Init memory init) external initializer {
        __AccessControlEnumerable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, init.admin);
        _grantRole(STAKING_MANAGER_ROLE, init.manager);
        _grantRole(ALLOCATOR_SERVICE_ROLE, init.allocatorService);
        _grantRole(INITIATOR_SERVICE_ROLE, init.initiatorService);

        _setRoleAdmin(STAKING_ALLOWLIST_MANAGER_ROLE, STAKING_MANAGER_ROLE);
        _setRoleAdmin(STAKING_ALLOWLIST_ROLE, STAKING_ALLOWLIST_MANAGER_ROLE);

        dETH = init.dETH;
        depositContract = init.depositContract;
        oracle = init.oracle;
        pauser = init.pauser;
        returnsAggregator = init.returnsAggregator;
        unstakeRequestsManager = init.unstakeRequestsManager;
        dapplinkBridge = init.dapplinkBridge;
        withdrawalWallet = init.withdrawalWallet;

        minimumStakeBound = 0.1 ether;
        minimumUnstakeBound = 0.01 ether;
        minimumDepositAmount = 32 ether;
        maximumDepositAmount = 32 ether;
        isStakingAllowlist = true;
        initializationBlockNumber = block.number;

        maximumDETHSupply = 1024 ether;
    }

    function stake(uint256 minDETHAmount, uint256 stakeAmount) external onlyDappLinkBridge payable {
        if (pauser.isStakingPaused()) {
            revert Paused();
        }

        if (isStakingAllowlist) {
            _checkRole(STAKING_ALLOWLIST_ROLE);
        }

        if (stakeAmount < minimumDepositAmount) {
            revert MinimumDepositAmountNotSatisfied();
        }

        uint256 dETHMintAmount = ethToDETH(stakeAmount);
        if (dETHMintAmount + dETH.totalSupply() > maximumDETHSupply) {
            revert MaximumDETHSupplyExceeded();
        }

        if (dETHMintAmount < minDETHAmount) {
            revert StakeBelowMinimumDETHAmount(dETHMintAmount, minDETHAmount);
        }
        unallocatedETH += stakeAmount;
        emit Staked(dapplinkBridge, stakeAmount, dETHMintAmount);
    }

    function unstakeRequest(uint128 dethAmount, uint128 minETHAmount) external  {
        _unstakeRequest(dethAmount, minETHAmount);
    }
    
    function _unstakeRequest(uint128 dethAmount, uint128 minETHAmount) internal {
        if (pauser.isUnstakeRequestsAndClaimsPaused()) {
            revert Paused();
        }

        if (dethAmount < minimumUnstakeBound) {
            revert MinimumUnstakeBoundNotSatisfied();
        }

        if (laveDethAmount > 0) {
            SafeERC20.safeTransferFrom(dETH, msg.sender, address(unstakeRequestsManager), laveDethAmount);
            emit UnstakeLaveAmount(msg.sender, laveDethAmount);
            batchDethAmount += laveDethAmount;
            laveDethAmount = 0;
        }

        batchDethAmount += dethAmount;
        if (batchDethAmount >= maximumDepositAmount) {
            laveDethAmount = batchDethAmount - maximumDepositAmount;
            uint256 transferAmount = batchDethAmount - laveDethAmount;
            SafeERC20.safeTransferFrom(dETH, msg.sender, address(unstakeRequestsManager), transferAmount);

            uint128 batchEthAmount = uint128(dETHToETH(batchDethAmount));

            uint256 batchRequestID = unstakeRequestsManager.create({requester: dapplinkBridge, dETHLocked: batchDethAmount, ethRequested: batchEthAmount});

            emit UnstakeBatchRequest({batchId: batchRequestID, batchEthAmount: batchEthAmount, batchDETHLocked: batchDethAmount});

            batchDethAmount = 0;

        } else {
            SafeERC20.safeTransferFrom(dETH, msg.sender, address(unstakeRequestsManager), dethAmount);
            emit UnstakeSingle({staker: msg.sender, dETHLocked: dethAmount});
        }
    }
    
    function claimUnstakeRequest(uint256 unstakeRequestID, address bridge, uint256 sourceChainId, uint256 destChainId, uint256 gasLimit) external onlyDappLinkBridge {
        if (pauser.isUnstakeRequestsAndClaimsPaused()) {
            revert Paused();
        }
        emit UnstakeRequestClaimed(unstakeRequestID, msg.sender, bridge, sourceChainId, destChainId);
        unstakeRequestsManager.claim(unstakeRequestID, msg.sender, bridge, sourceChainId, destChainId, gasLimit);
    }
    
    function unstakeRequestInfo(uint256 unstakeRequestID) external view returns (bool, uint256) {
        return unstakeRequestsManager.requestInfo(unstakeRequestID);
    }
    
    function reclaimAllocatedETHSurplus() external onlyRole(STAKING_MANAGER_ROLE) {
        unstakeRequestsManager.withdrawAllocatedETHSurplus();
    }
    
    function allocateETH(uint256 allocateToUnstakeRequestsManager, uint256 allocateToDeposits)
        external
        onlyRole(ALLOCATOR_SERVICE_ROLE)
    {
        if (pauser.isAllocateETHPaused()) {
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
            unstakeRequestsManager.allocateETH{value: allocateToUnstakeRequestsManager}();
        }
    }

    function initiateValidatorsWithDeposits(ValidatorParams[] calldata validators, bytes32 expectedDepositRoot)
        external
        onlyRole(INITIATOR_SERVICE_ROLE)
    {
        if (pauser.isInitiateValidatorsPaused()) {
            revert Paused();
        }
        if (validators.length == 0) {
            return;
        }

        bytes32 actualRoot = depositContract.get_deposit_root();
        if (expectedDepositRoot != actualRoot) {
            revert InvalidDepositRoot(actualRoot);
        }

        uint256 amountDeposited = 0;
        for (uint256 i = 0; i < validators.length; ++i) {
            ValidatorParams calldata validator = validators[i];

            if (usedValidators[validator.pubkey]) {
                revert PreviouslyUsedValidator();
            }

            if (validator.depositAmount < minimumDepositAmount) {
                revert MinimumValidatorDepositNotSatisfied();
            }

            if (validator.depositAmount > maximumDepositAmount) {
                revert MaximumValidatorDepositExceeded();
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
            depositContract.deposit{value: validator.depositAmount}({
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
    
    function ethToDETH(uint256 ethAmount) public view returns (uint256) {
        if (dETH.totalSupply() == 0) {
            return ethAmount;
        }
        return Math.mulDiv(
            ethAmount,
            dETH.totalSupply() * uint256(_BASIS_POINTS_DENOMINATOR - exchangeAdjustmentRate),
            totalControlled() * uint256(_BASIS_POINTS_DENOMINATOR)
        );
    }
    
    function dETHToETH(uint256 dETHAmount) public view returns (uint256) {
        if (dETH.totalSupply() == 0) {
            return dETHAmount;
        }
        return Math.mulDiv(dETHAmount, totalControlled(), dETH.totalSupply());
    }
    
    function totalControlled() public view returns (uint256) {
        OracleRecord memory record = oracle.latestRecord();
        uint256 total = 0;
        total += unallocatedETH;
        total += allocatedETHForDeposits;
        
        total += totalDepositedInValidators - record.cumulativeProcessedDepositAmount;
        total += record.currentTotalValidatorBalance;
        total += unstakeRequestsManager.balance();
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
        if (msg.sender != returnsAggregator) {
            revert NotReturnsAggregator();
        }
        _;
    }

    modifier onlyUnstakeRequestsManager() {
        if (msg.sender != address(unstakeRequestsManager)) {
            revert NotUnstakeRequestsManager();
        }
        _;
    }

     modifier onlyDappLinkBridge() {
        if (msg.sender != address(dapplinkBridge)) {
            revert NotDappLinkBridge();
        }
        _;
    }

    modifier notZeroAddress(address addr) {
        if (addr == address(0)) {
            revert ZeroAddress();
        }
        _;
    }

    function setMinimumStakeBound(uint256 minimumStakeBound_) external onlyRole(STAKING_MANAGER_ROLE) {
        minimumStakeBound = minimumStakeBound_;
        emit ProtocolConfigChanged(
            this.setMinimumStakeBound.selector, "setMinimumStakeBound(uint256)", abi.encode(minimumStakeBound_)
        );
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
    
    function setMaximumDepositAmount(uint256 maximumDepositAmount_) external onlyRole(STAKING_MANAGER_ROLE) {
        maximumDepositAmount = maximumDepositAmount_;
        emit ProtocolConfigChanged(
            this.setMaximumDepositAmount.selector, "setMaximumDepositAmount(uint256)", abi.encode(maximumDepositAmount_)
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
        revert DoesNotReceiveETH();
    }

    fallback() external payable {
        revert DoesNotReceiveETH();
    }
}
