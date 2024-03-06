// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/ReentrancyGuardUpgradeable.sol";
import "../interfaces/IFundingPooolManager.sol";
import "../interfaces/IDelegationManager.sol";
import "../interfaces/ISlasher.sol";
import "../../access/interface/IPauserRegistry.sol";
import "../../access/Pausable.sol";
import "../../libraries/EIP1271SignatureUtils.sol";



contract DelegationManager is Initializable, OwnableUpgradeable, Pausable, IDelegationManager, ReentrancyGuardUpgradeable {
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    bytes32 public constant STAKER_DELEGATION_TYPEHASH = keccak256("StakerDelegation(address staker,address operator,uint256 nonce,uint256 expiry)");
    bytes32 public constant DELEGATION_APPROVAL_TYPEHASH = keccak256("DelegationApproval(address staker,address operator,bytes32 salt,uint256 expiry)");

    uint8 internal constant PAUSED_NEW_DELEGATION = 0;
    uint8 internal constant PAUSED_ENTER_WITHDRAWAL_QUEUE = 1;
    uint8 internal constant PAUSED_EXIT_WITHDRAWAL_QUEUE = 2;
    uint256 internal immutable ORIGINAL_CHAIN_ID;
    uint256 public constant MAX_STAKER_OPT_OUT_WINDOW_BLOCKS = (180 days) / 12;

    bytes32 internal _DOMAIN_SEPARATOR;

    IFundingPooolManager public immutable fundingPoolManager;

    ISlasher public immutable slasher;

    uint256 public constant MAX_WITHDRAWAL_DELAY_BLOCKS = 50400;

    mapping(address => mapping(IFundingPoool => uint256)) public operatorShares;

    mapping(address => OperatorDetails) internal _operatorDetails;

    mapping(address => address) public delegatedTo;

    mapping(address => uint256) public stakerNonce;

    mapping(address => mapping(bytes32 => bool)) public delegationApproverSaltIsSpent;

    uint256 public withdrawalDelayBlocks;

    mapping(bytes32 => bool) public pendingWithdrawals;

    mapping(address => uint256) public cumulativeWithdrawalsQueued;

    IStakeRegistryStub public stakeRegistry;

    IFundingPoool public constant beaconChainETHPool = IFundingPoool(0xbeaC0eeEeeeeEEeEeEEEEeeEEeEeeeEeeEEBEaC0);

    modifier onlyFundingPoolManager() {
        require(
            msg.sender == address(fundingPoolManager),
            "DelegationManager: onlyFundingPoolManagerManager"
        );
        _;
    }

    constructor(IFundingPooolManager _fundingPoolManager, ISlasher _slasher) {
        _disableInitializers();
        fundingPoolManager = _fundingPoolManager;
        slasher = _slasher;
        ORIGINAL_CHAIN_ID = block.chainid;
    }

    function initialize(
        address initialOwner,
        IPauserRegistry _pauserRegistry,
        uint256 initialPausedStatus
    ) external initializer {
        _initializePauser(_pauserRegistry, initialPausedStatus);
        _DOMAIN_SEPARATOR = _calculateDomainSeparator();
        _transferOwnership(initialOwner);
    }

    /**
     * @notice Sets the address of the stakeRegistry
     * @param _stakeRegistry is the address of the StakeRegistry contract to call for stake updates when operator shares are changed
     * @dev Only callable once
     */
    function setStakeRegistry(IStakeRegistryStub _stakeRegistry) external onlyOwner {
        require(address(stakeRegistry) == address(0), "DelegationManager.setStakeRegistry: stakeRegistry already set");
        require(address(_stakeRegistry) != address(0), "DelegationManager.setStakeRegistry: stakeRegistry cannot be zero address");
        stakeRegistry = _stakeRegistry;
        emit StakeRegistrySet(_stakeRegistry);
    }

    function registerAsOperator(OperatorDetails calldata registeringOperatorDetails, string calldata metadataURI) external {
        require(
            _operatorDetails[msg.sender].earningsReceiver == address(0),
            "DelegationManager.registerAsOperator: operator has already registered"
        );
        _setOperatorDetails(msg.sender, registeringOperatorDetails);
        SignatureWithExpiry memory emptySignatureAndExpiry;
        _delegate(msg.sender, msg.sender, emptySignatureAndExpiry, bytes32(0));
        emit OperatorRegistered(msg.sender, registeringOperatorDetails);
        emit OperatorMetadataURIUpdated(msg.sender, metadataURI);
    }

    function modifyOperatorDetails(OperatorDetails calldata newOperatorDetails) external {
        require(isOperator(msg.sender), "DelegationManager.modifyOperatorDetails: caller must be an operator");
        _setOperatorDetails(msg.sender, newOperatorDetails);
    }

    function updateOperatorMetadataURI(string calldata metadataURI) external {
        require(isOperator(msg.sender), "DelegationManager.updateOperatorMetadataURI: caller must be an operator");
        emit OperatorMetadataURIUpdated(msg.sender, metadataURI);
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

    function setWithdrawalDelayBlocks(uint256 newWithdrawalDelayBlocks) external onlyOwner {
        require(
            newWithdrawalDelayBlocks <= MAX_WITHDRAWAL_DELAY_BLOCKS,
            "DelegationManager.setWithdrawalDelayBlocks: newWithdrawalDelayBlocks too high"
        );
        emit WithdrawalDelayBlocksSet(withdrawalDelayBlocks, newWithdrawalDelayBlocks);
        withdrawalDelayBlocks = newWithdrawalDelayBlocks;
    }

    function undelegate(address staker) external onlyWhenNotPaused(PAUSED_ENTER_WITHDRAWAL_QUEUE) returns (bytes32) {
        require(isDelegated(staker), "DelegationManager.undelegate: staker must be delegated to undelegate");
        address operator = delegatedTo[staker];
        require(!isOperator(staker), "DelegationManager.undelegate: operators cannot be undelegated");
        require(staker != address(0), "DelegationManager.undelegate: cannot undelegate zero address");
        require(
            msg.sender == staker ||
            msg.sender == operator ||
            msg.sender == _operatorDetails[operator].delegationApprover,
            "DelegationManager.undelegate: caller cannot undelegate staker"
        );

        (IFundingPoool[] memory pools, uint256[] memory shares)
        = getDelegatableShares(staker);

        if (msg.sender != staker) {
            emit StakerForceUndelegated(staker, operator);
        }

        emit StakerUndelegated(staker, operator);
        delegatedTo[staker] = address(0);

        if (pools.length == 0) {
            return bytes32(0);
        } else {
            return _removeSharesAndQueueWithdrawal({
                staker: staker,
                operator: operator,
                withdrawer: staker,
                pools: pools,
                shares: shares
            });
        }
    }

    function queueWithdrawals(
        QueuedWithdrawalParams[] calldata queuedWithdrawalParams
    ) external onlyWhenNotPaused(PAUSED_ENTER_WITHDRAWAL_QUEUE) returns (bytes32[] memory) {
        bytes32[] memory withdrawalRoots = new bytes32[](queuedWithdrawalParams.length);

        for (uint256 i = 0; i < queuedWithdrawalParams.length; i++) {
            require(queuedWithdrawalParams[i].fundingPools.length == queuedWithdrawalParams[i].shares.length, "DelegationManager.queueWithdrawal: input length mismatch");
            require(queuedWithdrawalParams[i].withdrawer != address(0), "DelegationManager.queueWithdrawal: must provide valid withdrawal address");

            address operator = delegatedTo[msg.sender];

            withdrawalRoots[i] = _removeSharesAndQueueWithdrawal({
                staker: msg.sender,
                operator: operator,
                withdrawer: queuedWithdrawalParams[i].withdrawer,
                pools: queuedWithdrawalParams[i].fundingPools,
                shares: queuedWithdrawalParams[i].shares
            });
        }
        return withdrawalRoots;
    }

    function completeQueuedWithdrawal(
        Withdrawal calldata withdrawal,
        IERC20[] calldata tokens,
        uint256 middlewareTimesIndex,
        bool receiveAsTokens
    ) external onlyWhenNotPaused(PAUSED_EXIT_WITHDRAWAL_QUEUE) nonReentrant {
        _completeQueuedWithdrawal(withdrawal, tokens, middlewareTimesIndex, receiveAsTokens);
    }


    function completeQueuedWithdrawals(
        Withdrawal[] calldata withdrawals,
        IERC20[][] calldata tokens,
        uint256[] calldata middlewareTimesIndexes,
        bool[] calldata receiveAsTokens
    ) external onlyWhenNotPaused(PAUSED_EXIT_WITHDRAWAL_QUEUE) nonReentrant {
        for (uint256 i = 0; i < withdrawals.length; ++i) {
            _completeQueuedWithdrawal(withdrawals[i], tokens[i], middlewareTimesIndexes[i], receiveAsTokens[i]);
        }
    }

    function migrateQueuedWithdrawals(IFundingPooolManager.DeprecatedStruct_QueuedWithdrawal[] memory withdrawalsToMigrate) external {
        for(uint256 i = 0; i < withdrawalsToMigrate.length;) {
            IFundingPooolManager.DeprecatedStruct_QueuedWithdrawal memory withdrawalToMigrate = withdrawalsToMigrate[i];

            (bool isDeleted, bytes32 oldWithdrawalRoot) = fundingPoolManager.migrateQueuedWithdrawal(withdrawalToMigrate);
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
                    fundingPools: withdrawalToMigrate.fundingPools,
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
        IFundingPoool strategy,
        uint256 shares
    ) external onlyFundingPoolManager {
        if (isDelegated(staker)) {
            address operator = delegatedTo[staker];

            _increaseOperatorShares({operator: operator, staker: staker, strategy: strategy, shares: shares});

            _pushOperatorStakeUpdate(operator);
        }
    }

    function decreaseDelegatedShares(
        address staker,
        IFundingPoool strategy,
        uint256 shares
    ) external onlyFundingPoolManager {
        if (isDelegated(staker)) {
            address operator = delegatedTo[staker];

            _decreaseOperatorShares({
                operator: operator,
                staker: staker,
                strategy: strategy,
                shares: shares
            });

            _pushOperatorStakeUpdate(operator);
        }
    }

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
    ) internal onlyWhenNotPaused(PAUSED_NEW_DELEGATION) {
        require(!isDelegated(staker), "DelegationManager._delegate: staker is already actively delegated");
        require(isOperator(operator), "DelegationManager._delegate: operator is not registered in ShadowX");

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
                _delegationApprover,
                approverDigestHash,
                approverSignatureAndExpiry.signature
            );
        }

        delegatedTo[staker] = operator;
        emit StakerDelegated(staker, operator);

        (IFundingPoool[] memory pools, uint256[] memory shares)
        = getDelegatableShares(staker);

        for (uint256 i = 0; i < pools.length;) {
            _increaseOperatorShares({
                operator: operator,
                staker: staker,
                strategy: pools[i],
                shares: shares[i]
            });

            unchecked { ++i; }
        }

        _pushOperatorStakeUpdate(operator);
    }

    function _completeQueuedWithdrawal(
        Withdrawal calldata withdrawal,
        IERC20[] calldata tokens,
        uint256,
        bool receiveAsTokens
    ) internal {
        bytes32 withdrawalRoot = calculateWithdrawalRoot(withdrawal);

        require(
            pendingWithdrawals[withdrawalRoot],
            "DelegationManager.completeQueuedAction: action is not in queue"
        );

        require(
            withdrawal.startBlock + withdrawalDelayBlocks <= block.number,
            "DelegationManager.completeQueuedAction: withdrawalDelayBlocks period has not yet passed"
        );

        require(
            msg.sender == withdrawal.withdrawer,
            "DelegationManager.completeQueuedAction: only withdrawer can complete action"
        );

        if (receiveAsTokens) {
            require(
                tokens.length == withdrawal.fundingPools.length,
                "DelegationManager.completeQueuedAction: input length mismatch"
            );
        }

        delete pendingWithdrawals[withdrawalRoot];

        if (receiveAsTokens) {
            for (uint256 i = 0; i < withdrawal.fundingPools.length; ) {
                _withdrawSharesAsTokens(
                    withdrawal.staker,
                    msg.sender,
                    withdrawal.fundingPools[i],
                    withdrawal.shares[i],
                    tokens[i]
                );
                unchecked { ++i; }
            }
        } else {
            address currentOperator = delegatedTo[msg.sender];
            for (uint256 i = 0; i < withdrawal.fundingPools.length; ) {
                if (withdrawal.fundingPools[i] == beaconChainETHPool) {
                    address staker = withdrawal.staker;
                    uint256 increaseInDelegateableShares = 1;
//                    uint256 increaseInDelegateableShares = fundingPoolManager.addShares(
//                        staker,
//                        withdrawal.fundingPools[i],
//                        withdrawal.shares[i]
//                    );
                    address podOwnerOperator = delegatedTo[staker];
                    if (podOwnerOperator != address(0)) {
                        _increaseOperatorShares({
                            operator: podOwnerOperator,
                            staker: staker,
                            strategy: withdrawal.fundingPools[i],
                            shares: increaseInDelegateableShares
                        });

                        _pushOperatorStakeUpdate(podOwnerOperator);
                    }
                } else {
                    fundingPoolManager.addShares(msg.sender, withdrawal.fundingPools[i], withdrawal.shares[i]);
                    if (currentOperator != address(0)) {
                        _increaseOperatorShares({
                            operator: currentOperator,
                            staker: msg.sender,
                            strategy: withdrawal.fundingPools[i],
                            shares: withdrawal.shares[i]
                        });
                    }
                }
                unchecked { ++i; }
            }
            _pushOperatorStakeUpdate(currentOperator);
        }

        emit WithdrawalCompleted(withdrawalRoot);
    }

    function _increaseOperatorShares(address operator, address staker, IFundingPoool strategy, uint256 shares) internal {
        operatorShares[operator][strategy] += shares;
        emit OperatorSharesIncreased(operator, staker, strategy, shares);
    }

    function _decreaseOperatorShares(address operator, address staker, IFundingPoool strategy, uint256 shares) internal {
        operatorShares[operator][strategy] -= shares;
        emit OperatorSharesDecreased(operator, staker, strategy, shares);
    }

    function _pushOperatorStakeUpdate(address operator) internal {
        if (address(stakeRegistry) != address(0)) {
            address[] memory operators = new address[](1);
            operators[0] = operator;
            stakeRegistry.updateStakes(operators);
        }
    }

    function _removeSharesAndQueueWithdrawal(
        address staker,
        address operator,
        address withdrawer,
        IFundingPoool[] memory pools,
        uint256[] memory shares
    ) internal returns (bytes32) {
        require(staker != address(0), "DelegationManager._removeSharesAndQueueWithdrawal: staker cannot be zero address");
        require(pools.length != 0, "DelegationManager._removeSharesAndQueueWithdrawal: pools cannot be empty");

        for (uint256 i = 0; i < pools.length;) {
            if (operator != address(0)) {
                _decreaseOperatorShares({
                    operator: operator,
                    staker: staker,
                    strategy: pools[i],
                    shares: shares[i]
                });
            }

            if (pools[i] == beaconChainETHPool) {
                fundingPoolManager.removeShares(staker, pools[i], shares[i]);
            } else {
                fundingPoolManager.removeShares(staker, pools[i], shares[i]);
            }

            unchecked { ++i; }
        }

        if (operator != address(0)) {
            _pushOperatorStakeUpdate(operator);
        }

        uint256 nonce = cumulativeWithdrawalsQueued[staker];
        cumulativeWithdrawalsQueued[staker]++;

        Withdrawal memory withdrawal = Withdrawal({
            staker: staker,
            delegatedTo: operator,
            withdrawer: withdrawer,
            nonce: nonce,
            startBlock: uint32(block.number),
            fundingPools: pools,
            shares: shares
        });

        bytes32 withdrawalRoot = calculateWithdrawalRoot(withdrawal);

        pendingWithdrawals[withdrawalRoot] = true;

        emit WithdrawalQueued(withdrawalRoot, withdrawal);
        return withdrawalRoot;
    }

    function _withdrawSharesAsTokens(address staker, address withdrawer, IFundingPoool fundingPool, uint256 shares, IERC20 token) internal {
        if (fundingPool == beaconChainETHPool) {
            fundingPoolManager.withdrawSharesAsTokens(withdrawer, fundingPool, shares, token);
        } else {
            fundingPoolManager.withdrawSharesAsTokens(withdrawer, fundingPool, shares, token);
        }
    }

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

    function getDelegatableShares(address staker) public view returns (IFundingPoool[] memory, uint256[] memory) {
        // int256 podShares = fundingPoolManager.podOwnerShares(staker);
        int256 podShares = 10;
        (IFundingPoool[] memory fundingPoolManagerStrats, uint256[] memory fundingPoolManagerShares)
        = fundingPoolManager.getDeposits(staker);

        if (podShares <= 0) {
            return (fundingPoolManagerStrats, fundingPoolManagerShares);
        }

        IFundingPoool[] memory pools;
        uint256[] memory shares;

        if (fundingPoolManagerStrats.length == 0) {
            pools = new IFundingPoool[](1);
            shares = new uint256[](1);
            pools[0] = beaconChainETHPool;
            shares[0] = uint256(podShares);
        } else {
            pools = new IFundingPoool[](fundingPoolManagerStrats.length + 1);
            shares = new uint256[](pools.length);

            for (uint256 i = 0; i < fundingPoolManagerStrats.length; ) {
                pools[i] = fundingPoolManagerStrats[i];
                shares[i] = fundingPoolManagerShares[i];

                unchecked { ++i; }
            }

            pools[pools.length - 1] = beaconChainETHPool;
            shares[pools.length - 1] = uint256(podShares);
        }

        return (pools, shares);
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
            abi.encode(DELEGATION_APPROVAL_TYPEHASH, _delegationApprover, staker, operator, approverSalt, expiry)
        );
        bytes32 approverDigestHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator(), approverStructHash));
        return approverDigestHash;
    }

    function _calculateDomainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes("ShadowX")), block.chainid, address(this)));
    }
}
