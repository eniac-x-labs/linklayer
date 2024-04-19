// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../libraries/EIP1271SignatureUtils.sol";
import "./DelegationManagerStorage.sol";
import {L2Base} from "@/contracts/l2/core/L2Base.sol";

contract DelegationManager is L2Base, DelegationManagerStorage {
    uint8 internal constant PAUSED_NEW_DELEGATION = 0;

    uint8 internal constant PAUSED_ENTER_WITHDRAWAL_QUEUE = 1;

    uint8 internal constant PAUSED_EXIT_WITHDRAWAL_QUEUE = 2;

    uint256 internal immutable ORIGINAL_CHAIN_ID;

    uint256 public constant MAX_STAKER_OPT_OUT_WINDOW_BLOCKS = (180 days) / 12;



    /*******************************************************************************
                            INITIALIZING FUNCTIONS
    *******************************************************************************/
    constructor() {
        _disableInitializers();
        ORIGINAL_CHAIN_ID = block.chainid;
    }

    function initialize(
        address initialOwner,
        uint256 _minWithdrawalDelayBlocks,
        address[] calldata _strategies,
        uint256[] calldata _withdrawalDelayBlocks
    ) external initializer {
        _DOMAIN_SEPARATOR = _calculateDomainSeparator();
        __L2Base_init(initialOwner);
        _setMinWithdrawalDelayBlocks(_minWithdrawalDelayBlocks);
        _setStrategyWithdrawalDelayBlocks(_strategies, _withdrawalDelayBlocks);
    }

    /*******************************************************************************
                            EXTERNAL FUNCTIONS 
    *******************************************************************************/
    function registerAsOperator(
        OperatorDetails calldata registeringOperatorDetails,
        string calldata nodeUrl
    ) external {
        require(
            _operatorDetails[msg.sender].earningsReceiver == address(0),
            "DelegationManager.registerAsOperator: operator has already registered"
        );
        _setOperatorDetails(msg.sender, registeringOperatorDetails);
        SignatureWithExpiry memory emptySignatureAndExpiry;
        _delegate(msg.sender, msg.sender, emptySignatureAndExpiry, bytes32(0));
        emit OperatorRegistered(msg.sender, registeringOperatorDetails);
        emit OperatorNodeUrlUpdated(msg.sender, nodeUrl);
    }

    function modifyOperatorDetails(OperatorDetails calldata newOperatorDetails) external {
        require(isOperator(msg.sender), "DelegationManager.modifyOperatorDetails: caller must be an operator");
        _setOperatorDetails(msg.sender, newOperatorDetails);
    }

    function updateOperatorNodeUrl(string calldata nodeUrl) external {
        require(isOperator(msg.sender), "DelegationManager.updateOperatorNodeUrl: caller must be an operator");
        emit OperatorNodeUrlUpdated(msg.sender, nodeUrl);
    }

    function delegateTo(
        address operator,
        SignatureWithExpiry memory approverSignatureAndExpiry,
        bytes32 approverSalt
    ) external {
        _delegate(msg.sender, operator, approverSignatureAndExpiry, approverSalt);
    }

    function delegateToBySignature(
        address staker,
        address operator,
        SignatureWithExpiry memory stakerSignatureAndExpiry,
        SignatureWithExpiry memory approverSignatureAndExpiry,
        bytes32 approverSalt
    ) external {
        require(
            stakerSignatureAndExpiry.expiry >= block.timestamp,
            "DelegationManager.delegateToBySignature: staker signature expired"
        );

        uint256 currentStakerNonce = stakerNonce[staker];
        bytes32 stakerDigestHash = calculateStakerDelegationDigestHash(
            staker,
            currentStakerNonce,
            operator,
            stakerSignatureAndExpiry.expiry
        );
        unchecked {
            stakerNonce[staker] = currentStakerNonce + 1;
        }

        EIP1271SignatureUtils.checkSignature_EIP1271(staker, stakerDigestHash, stakerSignatureAndExpiry.signature);

        _delegate(staker, operator, approverSignatureAndExpiry, approverSalt);
    }

    function undelegate(address staker) external returns (bytes32[] memory withdrawalRoots) {
        require(getL2Pauser().isUnDelegate(), "DelegationManager:undelegate paused");
        require(isDelegated(staker), "DelegationManager.undelegate: staker must be delegated to undelegate");
        require(!isOperator(staker), "DelegationManager.undelegate: operators cannot be undelegated");
        require(staker != address(0), "DelegationManager.undelegate: cannot undelegate zero address");
        address operator = delegatedTo[staker];
        require(
            msg.sender == staker ||
                msg.sender == operator ||
                msg.sender == _operatorDetails[operator].delegationApprover,
            "DelegationManager.undelegate: caller cannot undelegate staker"
        );

        (address[] memory strategies, uint256[] memory shares) = getDelegatableShares(staker);

        if (msg.sender != staker) {
            emit StakerForceUndelegated(staker, operator);
        }

        emit StakerUndelegated(staker, operator);
        delegatedTo[staker] = address(0);

        if (strategies.length == 0) {
            withdrawalRoots = new bytes32[](0);
        } else {
            withdrawalRoots = new bytes32[](strategies.length);
            for (uint256 i = 0; i < strategies.length; i++) {
                address[] memory singleStrategy = new address[](1);
                uint256[] memory singleShare = new uint256[](1);
                singleStrategy[0] = strategies[i];
                singleShare[0] = shares[i];

                withdrawalRoots[i] = _removeSharesAndQueueWithdrawal({
                    staker: staker,
                    operator: operator,
                    withdrawer: staker,
                    strategies: singleStrategy,
                    shares: singleShare
                });
            }
        }

        return withdrawalRoots;
    }

    function queueWithdrawals(
        QueuedWithdrawalParams[] calldata queuedWithdrawalParams
    ) external returns (bytes32[] memory) {
        require(getL2Pauser().isStakerWithdraw(), "DelegationManager:queueWithdrawals paused");
        bytes32[] memory withdrawalRoots = new bytes32[](queuedWithdrawalParams.length);
        address operator = delegatedTo[msg.sender];

        for (uint256 i = 0; i < queuedWithdrawalParams.length; i++) {
            require(queuedWithdrawalParams[i].strategies.length == queuedWithdrawalParams[i].shares.length, "DelegationManager.queueWithdrawal: input length mismatch");
            // require(queuedWithdrawalParams[i].withdrawer == msg.sender, "DelegationManager.queueWithdrawal: withdrawer must be staker");
            withdrawalRoots[i] = _removeSharesAndQueueWithdrawal({
                staker: queuedWithdrawalParams[i].withdrawer,
                operator: operator,
                withdrawer: queuedWithdrawalParams[i].withdrawer,
                strategies: queuedWithdrawalParams[i].strategies,
                shares: queuedWithdrawalParams[i].shares
            });
        }
        return withdrawalRoots;
    }

    function completeQueuedWithdrawal(
        Withdrawal calldata withdrawal,
        IERC20 weth,
        uint256 middlewareTimesIndex,
        bool receiveAsWeth
    ) external nonReentrant {
       require(getL2Pauser().isStakerWithdraw(), "DelegationManager:completeQueuedWithdrawal paused");
        _completeQueuedWithdrawal(withdrawal, weth, middlewareTimesIndex, receiveAsWeth);
    }

    function completeQueuedWithdrawals(
        Withdrawal[] calldata withdrawals,
        IERC20 weth,
        uint256[] calldata middlewareTimesIndexes,
        bool[] calldata receiveAsWeth
    ) external nonReentrant {
        require(getL2Pauser().isStakerWithdraw(), "DelegationManager:completeQueuedWithdrawals paused");
        for (uint256 i = 0; i < withdrawals.length; ++i) {
            _completeQueuedWithdrawal(withdrawals[i], weth, middlewareTimesIndexes[i], receiveAsWeth[i]);
        }
    }

    function migrateQueuedWithdrawals(IStrategyManager.DeprecatedStruct_QueuedWithdrawal[] memory withdrawalsToMigrate) external {
        for(uint256 i = 0; i < withdrawalsToMigrate.length;) {
            IStrategyManager.DeprecatedStruct_QueuedWithdrawal memory withdrawalToMigrate = withdrawalsToMigrate[i];
            (bool isDeleted, bytes32 oldWithdrawalRoot) = getStrategyManager().migrateQueuedWithdrawal(withdrawalToMigrate);
            if (isDeleted) {
                address staker = withdrawalToMigrate.staker;
                uint256 nonce = cumulativeWithdrawalsQueued[staker];
                cumulativeWithdrawalsQueued[staker]++;

                Withdrawal memory migratedWithdrawal = Withdrawal({
                    staker: staker,
                    delegatedTo: withdrawalToMigrate.delegatedAddress,
                    withdrawer: withdrawalToMigrate.withdrawerAndNonce.withdrawer,
                    nonce: nonce,
                    startBlock: withdrawalToMigrate.withdrawalStartBlock,
                    strategies: withdrawalToMigrate.strategies,
                    shares: withdrawalToMigrate.shares
                });
                bytes32 newRoot = calculateWithdrawalRoot(migratedWithdrawal);
                require(!pendingWithdrawals[newRoot], "DelegationManager.migrateQueuedWithdrawals: withdrawal already exists");
                pendingWithdrawals[newRoot] = true;
                emit WithdrawalQueued(newRoot, migratedWithdrawal);
                emit WithdrawalMigrated(oldWithdrawalRoot, newRoot);
            }
            unchecked {
                ++i;
            }
        }
        
    }

    function increaseDelegatedShares(
        address staker,
        address strategy,
        uint256 shares
    ) external onlyStrategyManager {
        if (isDelegated(staker)) {
            address operator = delegatedTo[staker];
            _increaseOperatorShares({operator: operator, staker: staker, strategy: strategy, shares: shares});
        }
    }

    function decreaseDelegatedShares(
        address staker,
        address strategy,
        uint256 shares
    ) external onlyStrategyManager {
        if (isDelegated(staker)) {
            address operator = delegatedTo[staker];
            _decreaseOperatorShares({
                operator: operator,
                staker: staker,
                strategy: strategy,
                shares: shares
            });
        }
    }

    function setMinWithdrawalDelayBlocks(uint256 newMinWithdrawalDelayBlocks) external onlyOwner {
        _setMinWithdrawalDelayBlocks(newMinWithdrawalDelayBlocks);
    }

    function setStrategyWithdrawalDelayBlocks(
        address[] calldata strategies,
        uint256[] calldata withdrawalDelayBlocks
    ) external onlyOwner {
        _setStrategyWithdrawalDelayBlocks(strategies, withdrawalDelayBlocks);
    }

    /*******************************************************************************
                            INTERNAL FUNCTIONS
    *******************************************************************************/
    function _setOperatorDetails(address operator, OperatorDetails calldata newOperatorDetails) internal {
        require(
            newOperatorDetails.earningsReceiver != address(0),
            "DelegationManager._setOperatorDetails: cannot set `earningsReceiver` to zero address"
        );
        require(
            newOperatorDetails.stakerOptOutWindowBlocks <= MAX_STAKER_OPT_OUT_WINDOW_BLOCKS,
            "DelegationManager._setOperatorDetails: stakerOptOutWindowBlocks cannot be > MAX_STAKER_OPT_OUT_WINDOW_BLOCKS"
        );
        require(
            newOperatorDetails.stakerOptOutWindowBlocks >= _operatorDetails[operator].stakerOptOutWindowBlocks,
            "DelegationManager._setOperatorDetails: stakerOptOutWindowBlocks cannot be decreased"
        );
        _operatorDetails[operator] = newOperatorDetails;
        emit OperatorDetailsModified(msg.sender, newOperatorDetails);
    }

    function _delegate(
        address staker,
        address operator,
        SignatureWithExpiry memory approverSignatureAndExpiry,
        bytes32 approverSalt
    ) internal {
        require(getL2Pauser().isDelegate(), "DelegationManager:isDelegate paused");
        require(!isDelegated(staker), "DelegationManager._delegate: staker is already actively delegated");
        require(isOperator(operator), "DelegationManager._delegate: operator is not registered in DappLink");

        address _delegationApprover = _operatorDetails[operator].delegationApprover;

        if (_delegationApprover != address(0) && msg.sender != _delegationApprover && msg.sender != operator) {
            require(
                approverSignatureAndExpiry.expiry >= block.timestamp,
                "DelegationManager._delegate: approver signature expired"
            );

            require(
                !delegationApproverSaltIsSpent[_delegationApprover][approverSalt],
                "DelegationManager._delegate: approverSalt already spent"
            );
            delegationApproverSaltIsSpent[_delegationApprover][approverSalt] = true;

            bytes32 approverDigestHash = calculateDelegationApprovalDigestHash(
                staker,
                operator,
                _delegationApprover,
                approverSalt,
                approverSignatureAndExpiry.expiry
            );

             
            EIP1271SignatureUtils.checkSignature_EIP1271(
                staker,
                approverDigestHash,
                approverSignatureAndExpiry.signature
            );
        }

        delegatedTo[staker] = operator;
        emit StakerDelegated(staker, operator);

        (address[] memory strategies, uint256[] memory shares)
            = getDelegatableShares(staker);

        for (uint256 i = 0; i < strategies.length;) {
            _increaseOperatorShares({
                operator: operator,
                staker: staker,
                strategy: strategies[i],
                shares: shares[i]
            });

            unchecked { ++i; }
        }
    }

    function _completeQueuedWithdrawal(
        Withdrawal calldata withdrawal,
        IERC20 weth,
        uint256,
        bool receiveAsWeth
    ) internal {
        bytes32 withdrawalRoot = calculateWithdrawalRoot(withdrawal);

        // require(
        //     pendingWithdrawals[withdrawalRoot], 
        //     "DelegationManager._completeQueuedWithdrawal: action is not in queue"
        // );

        // require(
        //     withdrawal.startBlock + minWithdrawalDelayBlocks <= block.number, 
        //     "DelegationManager._completeQueuedWithdrawal: minWithdrawalDelayBlocks period has not yet passed"
        // );

        require(
            msg.sender == withdrawal.withdrawer, 
            "DelegationManager._completeQueuedWithdrawal: only withdrawer can complete action"
        );

        delete pendingWithdrawals[withdrawalRoot];
        address currentOperator = delegatedTo[msg.sender];
        if (receiveAsWeth) {
            for (uint256 i = 0; i < withdrawal.strategies.length; ) {
                require(
                    withdrawal.startBlock + strategyWithdrawalDelayBlocks[withdrawal.strategies[i]] <= block.number,
                    "DelegationManager._completeQueuedWithdrawal: withdrawalDelayBlocks period has not yet passed for this strategy"
                );

                _withdrawSharesAsWeth({
                    withdrawer: msg.sender,
                    strategy: withdrawal.strategies[i],
                    shares: withdrawal.shares[i],
                    weth: weth
                });
                unchecked { ++i; }
                emit WithdrawalCompleted(currentOperator, msg.sender, withdrawal.strategies[i], withdrawal.shares[i]);
            }
        } else {
          
            for (uint256 i = 0; i < withdrawal.strategies.length; ) {
                // require(
                //     withdrawal.startBlock + strategyWithdrawalDelayBlocks[withdrawal.strategies[i]] <= block.number, 
                //     "DelegationManager._completeQueuedWithdrawal: withdrawalDelayBlocks period has not yet passed for this strategy"
                // );
                getStrategyManager().addShares(msg.sender, weth, withdrawal.strategies[i], withdrawal.shares[i]);
                if (currentOperator != address(0)) {
                    _increaseOperatorShares({
                        operator: currentOperator,
                        staker: msg.sender,
                        strategy: withdrawal.strategies[i],
                        shares: withdrawal.shares[i]
                    });
                }
                unchecked { ++i; }
                emit WithdrawalCompleted(currentOperator, msg.sender, withdrawal.strategies[i], withdrawal.shares[i]);
            }
        }
        // emit WithdrawalCompleted(withdrawalRoot);
    }

    function _increaseOperatorShares(address operator, address staker, address strategy, uint256 shares) internal {
        operatorShares[operator][strategy] += shares;
        stakerStrategyOperatorShares[operator][strategy][operator] += shares;
        emit OperatorSharesIncreased(operator, staker, strategy, shares);
    }

    function _decreaseOperatorShares(address operator, address staker, address strategy, uint256 shares) internal {
        operatorShares[operator][strategy] -= shares;
        stakerStrategyOperatorShares[operator][strategy][operator] -= shares;
        emit OperatorSharesDecreased(operator, staker, strategy, shares);
    }

    function _removeSharesAndQueueWithdrawal(
        address staker, 
        address operator,
        address withdrawer,
        address[] memory strategies, 
        uint256[] memory shares
    ) internal returns (bytes32) {
        require(staker != address(0), "DelegationManager._removeSharesAndQueueWithdrawal: staker cannot be zero address");
        require(strategies.length != 0, "DelegationManager._removeSharesAndQueueWithdrawal: strategies cannot be empty");
        for (uint256 i = 0; i < strategies.length;) {
             uint256 l1BackShares = getStrategyManager().getStakerStrategyL1BackShares(staker, strategies[i]);
             if (l1BackShares >= shares[i]) {
                 if (operator != address(0)) {
                    _decreaseOperatorShares({
                        operator: operator,
                        staker: staker,
                        strategy: strategies[i],
                        shares: shares[i]
                    });
                }
                require(
                    staker == withdrawer || !getStrategyManager().thirdPartyTransfersForbidden(strategies[i]),
                    "DelegationManager._removeSharesAndQueueWithdrawal: withdrawer must be same address as staker if thirdPartyTransfersForbidden are set"
                );
                getStrategyManager().removeShares(staker, strategies[i], shares[i]);

                unchecked { ++i; }
             }
        }

        uint256 nonce = cumulativeWithdrawalsQueued[staker];
        cumulativeWithdrawalsQueued[staker]++;

        Withdrawal memory withdrawal = Withdrawal({
            staker: staker,
            delegatedTo: operator,
            withdrawer: withdrawer,
            nonce: nonce,
            startBlock: uint32(block.number),
            strategies: strategies,
            shares: shares
        });

        bytes32 withdrawalRoot = calculateWithdrawalRoot(withdrawal);

        pendingWithdrawals[withdrawalRoot] = true;

        emit WithdrawalQueued(withdrawalRoot, withdrawal);
        return withdrawalRoot;
    }

    function _withdrawSharesAsWeth(address withdrawer, address strategy, uint256 shares, IERC20 weth) internal {
        getStrategyManager().withdrawSharesAsWeth(withdrawer, strategy, shares, weth);
    }

    function _setMinWithdrawalDelayBlocks(uint256 _minWithdrawalDelayBlocks) internal {
        require(
            _minWithdrawalDelayBlocks <= MAX_WITHDRAWAL_DELAY_BLOCKS,
            "DelegationManager._setMinWithdrawalDelayBlocks: _minWithdrawalDelayBlocks cannot be > MAX_WITHDRAWAL_DELAY_BLOCKS"
        );
        emit MinWithdrawalDelayBlocksSet(minWithdrawalDelayBlocks, _minWithdrawalDelayBlocks);
        minWithdrawalDelayBlocks = _minWithdrawalDelayBlocks;
    }

    function _setStrategyWithdrawalDelayBlocks(
        address[] calldata _strategies,
        uint256[] calldata _withdrawalDelayBlocks
    ) internal {
        require(
            _strategies.length == _withdrawalDelayBlocks.length,
            "DelegationManager._setStrategyWithdrawalDelayBlocks: input length mismatch"
        );
        uint256 numStrats = _strategies.length;
        for (uint256 i = 0; i < numStrats; ++i) {
            address strategy = _strategies[i];
            uint256 prevStrategyWithdrawalDelayBlocks = strategyWithdrawalDelayBlocks[strategy];
            uint256 newStrategyWithdrawalDelayBlocks = _withdrawalDelayBlocks[i];
            require(
                newStrategyWithdrawalDelayBlocks <= MAX_WITHDRAWAL_DELAY_BLOCKS,
                "DelegationManager._setStrategyWithdrawalDelayBlocks: _withdrawalDelayBlocks cannot be > MAX_WITHDRAWAL_DELAY_BLOCKS"
            );

            strategyWithdrawalDelayBlocks[strategy] = newStrategyWithdrawalDelayBlocks;
            emit StrategyWithdrawalDelayBlocksSet(
                strategy,
                prevStrategyWithdrawalDelayBlocks,
                newStrategyWithdrawalDelayBlocks
            );
        }
    }

    /*******************************************************************************
                            VIEW FUNCTIONS
    *******************************************************************************/
    function domainSeparator() public view returns (bytes32) {
        if (block.chainid == ORIGINAL_CHAIN_ID) {
            return _DOMAIN_SEPARATOR;
        } else {
            return _calculateDomainSeparator();
        }
    }

    function isDelegated(address staker) public view returns (bool) {
        return (delegatedTo[staker] != address(0));
    }

    function isOperator(address operator) public view returns (bool) {
        return (_operatorDetails[operator].earningsReceiver != address(0));
    }

    function operatorDetails(address operator) external view returns (OperatorDetails memory) {
        return _operatorDetails[operator];
    }

    function earningsReceiver(address operator) external view returns (address) {
        return _operatorDetails[operator].earningsReceiver;
    }

    function delegationApprover(address operator) external view returns (address) {
        return _operatorDetails[operator].delegationApprover;
    }

    function stakerOptOutWindowBlocks(address operator) external view returns (uint256) {
        return _operatorDetails[operator].stakerOptOutWindowBlocks;
    }

    function getOperatorShares(
        address operator,
        address[] memory strategies
    ) public view returns (uint256[] memory) {
        uint256[] memory shares = new uint256[](strategies.length);
        for (uint256 i = 0; i < strategies.length; ++i) {
            shares[i] = operatorShares[operator][strategies[i]];
        }
        return shares;
    }

    function getDelegatableShares(address staker) public view returns (address[] memory, uint256[] memory) {
        (address[] memory strategyManagerStrats, uint256[] memory strategyManagerShares) = getStrategyManager().getDeposits(staker);
        return (strategyManagerStrats, strategyManagerShares);
    }

    function getWithdrawalDelay(address[] calldata strategies) public view returns (uint256) {
        uint256 withdrawalDelay = minWithdrawalDelayBlocks;
        for (uint256 i = 0; i < strategies.length; ++i) {
            uint256 currWithdrawalDelay = strategyWithdrawalDelayBlocks[strategies[i]];
            if (currWithdrawalDelay > withdrawalDelay) {
                withdrawalDelay = currWithdrawalDelay;
            }
        }
        return withdrawalDelay;
    }

    function calculateWithdrawalRoot(Withdrawal memory withdrawal) public pure returns (bytes32) {
        return keccak256(abi.encode(withdrawal));
    }

    function calculateCurrentStakerDelegationDigestHash(
        address staker,
        address operator,
        uint256 expiry
    ) external view returns (bytes32) {
        uint256 currentStakerNonce = stakerNonce[staker];
        return calculateStakerDelegationDigestHash(staker, currentStakerNonce, operator, expiry);
    }

    function calculateStakerDelegationDigestHash(
        address staker,
        uint256 _stakerNonce,
        address operator,
        uint256 expiry
    ) public view returns (bytes32) {
        bytes32 stakerStructHash = keccak256(
            abi.encode(STAKER_DELEGATION_TYPEHASH, staker, operator, _stakerNonce, expiry)
        );

        bytes32 stakerDigestHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator(), stakerStructHash));
        return stakerDigestHash;
    }

    function calculateDelegationApprovalDigestHash(
        address staker,
        address operator,
        address _delegationApprover,
        bytes32 approverSalt,
        uint256 expiry
    ) public view returns (bytes32) {
        bytes32 approverStructHash = keccak256(
            abi.encode(DELEGATION_APPROVAL_TYPEHASH, staker, operator, _delegationApprover,approverSalt, expiry)
        );

        bytes32 approverDigestHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator(), approverStructHash));
        return approverDigestHash;
    }

    function _calculateDomainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes("DappLink")), block.chainid, address(this)));
    }
}
