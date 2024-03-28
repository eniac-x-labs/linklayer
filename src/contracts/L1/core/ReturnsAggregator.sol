// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Initializable } from "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import { AccessControlEnumerableUpgradeable } from "@openzeppelin-upgrades/contracts/access/extensions/AccessControlEnumerableUpgradeable.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { ProtocolEvents } from "../interfaces/ProtocolEvents.sol";
import { IL1Pauser } from "../../access/interface/IL1Pauser.sol";
import { IOracleReadRecord, OracleRecord } from "../interfaces/IOracleManager.sol";
import { IStakingManagerReturnsWrite } from "../interfaces/IStakingManager.sol";
import { IReturnsAggregator } from "../interfaces/IReturnsAggregator.sol";

import { ReturnsReceiver } from "./ReturnsReceiver.sol";
import "../../libraries/SafeCall.sol";


contract ReturnsAggregator is Initializable, AccessControlEnumerableUpgradeable, ProtocolEvents, IReturnsAggregator {
    bytes32 public constant AGGREGATOR_MANAGER_ROLE = keccak256("AGGREGATOR_MANAGER_ROLE");

    uint16 internal constant _BASIS_POINTS_DENOMINATOR = 10_000;

    IStakingManagerReturnsWrite public staking;

    IOracleReadRecord public oracle;

    ReturnsReceiver public consensusLayerReceiver;

    ReturnsReceiver public executionLayerReceiver;

    IL1Pauser public pauser;

    address payable public feesReceiver;

    uint16 public feesBasisPoints;

    uint256 public gasLimit = 21000;

    struct Init {
        address admin;
        address manager;
        IOracleReadRecord oracle;
        IL1Pauser pauser;
        ReturnsReceiver consensusLayerReceiver;
        ReturnsReceiver executionLayerReceiver;
        IStakingManagerReturnsWrite staking;
        address payable feesReceiver;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(Init memory init) external initializer {
        __AccessControlEnumerable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, init.admin);
        _grantRole(AGGREGATOR_MANAGER_ROLE, init.manager);

        oracle = init.oracle;
        pauser = init.pauser;
        consensusLayerReceiver = init.consensusLayerReceiver;
        executionLayerReceiver = init.executionLayerReceiver;
        staking = init.staking;
        feesReceiver = init.feesReceiver;
        feesBasisPoints = 1_000;
    }

    function processReturns(uint256 rewardAmount, uint256 principalAmount, bool shouldIncludeELRewards, address bridge, address l2Strategy, uint256 sourceChainId, uint256 destChainId)
        external
        assertBalanceUnchanged
    {
        if (msg.sender != address(oracle)) {
            revert NotOracle();
        }

        uint256 clTotal = rewardAmount + principalAmount;
        uint256 totalRewards = rewardAmount;

        uint256 elRewards = 0;
        if (shouldIncludeELRewards) {
            elRewards = address(executionLayerReceiver).balance;
            totalRewards += elRewards;
        }

        uint256 fees = Math.mulDiv(feesBasisPoints, totalRewards, _BASIS_POINTS_DENOMINATOR);

        address payable self = payable(address(this));
        if (elRewards > 0) {
            SafeCall.callWithMinGas(
                bridge,
                gasLimit,
                elRewards,
                abi.encodeWithSignature("BridgeInitiateETH(uint256,uint256,address)", sourceChainId, destChainId, l2Strategy)
            );
        }
        if (clTotal > 0) {
            consensusLayerReceiver.transfer(self, clTotal);
        }

        uint256 netReturns = clTotal + elRewards - fees;
        if (netReturns > 0) {
            staking.receiveReturns{value: netReturns}();
        }

        if (fees > 0) {
            emit FeesCollected(fees);
            Address.sendValue(feesReceiver, fees);
        }
    }

    function setFeesReceiver(address payable newReceiver)
        external
        onlyRole(AGGREGATOR_MANAGER_ROLE)
        notZeroAddress(newReceiver)
    {
        feesReceiver = newReceiver;
        emit ProtocolConfigChanged(this.setFeesReceiver.selector, "setFeesReceiver(address)", abi.encode(newReceiver));
    }

    function setFeeBasisPoints(uint16 newBasisPoints) external onlyRole(AGGREGATOR_MANAGER_ROLE) {
        if (newBasisPoints > _BASIS_POINTS_DENOMINATOR) {
            revert InvalidConfiguration();
        }

        feesBasisPoints = newBasisPoints;
        emit ProtocolConfigChanged(
            this.setFeeBasisPoints.selector, "setFeeBasisPoints(uint16)", abi.encode(newBasisPoints)
        );
    }

    receive() external payable {}
    
    modifier notZeroAddress(address addr) {
        if (addr == address(0)) {
            revert ZeroAddress();
        }
        _;
    }

    modifier assertBalanceUnchanged() {
        uint256 before = address(this).balance;
        _;
        assert(address(this).balance == before);
    }
}
