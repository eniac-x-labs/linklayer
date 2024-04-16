// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import {L1Base} from "@/contracts/L1/core/L1Base.sol";
import { IOracleReadRecord, OracleRecord } from "../interfaces/IOracleManager.sol";
import { IStakingManagerReturnsWrite } from "../interfaces/IStakingManager.sol";
import { IReturnsAggregator } from "../interfaces/IReturnsAggregator.sol";

import { ReturnsReceiver } from "./ReturnsReceiver.sol";
import "../../libraries/SafeCall.sol";


contract ReturnsAggregator is L1Base, IReturnsAggregator {
    bytes32 public constant AGGREGATOR_MANAGER_ROLE = keccak256("AGGREGATOR_MANAGER_ROLE");

    uint16 internal constant _BASIS_POINTS_DENOMINATOR = 10_000;

    address payable public feesReceiver;

    uint16 public feesBasisPoints;

    uint256 public gasLimit = 21000;

    struct Init {
        address admin;
        address manager;
        address payable feesReceiver;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(Init memory init) external initializer {
        __L1Base_init(init.admin);
        _grantRole(AGGREGATOR_MANAGER_ROLE, init.manager);
        feesReceiver = init.feesReceiver;
        feesBasisPoints = 1_000;
    }

    function processReturns(uint256 rewardAmount, uint256 principalAmount, bool shouldIncludeELRewards, address bridge, address l2Strategy, uint256 sourceChainId, uint256 destChainId)
        external
        assertBalanceUnchanged
    {
        if (msg.sender != getLocator().oracleManager()) {
            revert NotOracle();
        }

        uint256 clTotal = rewardAmount + principalAmount;
        uint256 totalRewards = rewardAmount;

        uint256 elRewards = 0;
        if (shouldIncludeELRewards) {
            elRewards = getLocator().executionLayerReceiver().balance;
            totalRewards += elRewards;
        }

        uint256 fees = Math.mulDiv(feesBasisPoints, totalRewards, _BASIS_POINTS_DENOMINATOR);

        address payable self = payable(address(this));
        if (elRewards > 0) {
            bool success = SafeCall.callWithMinGas(
                bridge,
                gasLimit,
                elRewards,
                abi.encodeWithSignature("BridgeInitiateETH(uint256,uint256,address)", sourceChainId, destChainId, l2Strategy)
            );
            require(success, "BridgeInitiateETH failed");
        }
        if (clTotal > 0) {
            ReturnsReceiver(payable (getLocator().consensusLayerReceiver())).transfer(self, clTotal);
        }

        uint256 netReturns = clTotal + elRewards - fees;
        if (netReturns > 0) {
            IStakingManagerReturnsWrite(getLocator().stakingManager()).receiveReturns{value: netReturns}();
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
    
    modifier assertBalanceUnchanged() {
        uint256 before = address(this).balance;
        _;
        assert(address(this).balance == before);
    }
}
