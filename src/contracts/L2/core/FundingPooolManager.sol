// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../access/Pausable.sol";
import "../libraries/EIP1271SignatureUtils.sol";
import "../interfaces/IFundingPooolManager.sol";



contract FundingPooolManager is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, Pausable {
    using SafeERC20 for IERC20;

    uint8 internal constant PAUSED_DEPOSITS = 0;
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    bytes32 public constant DEPOSIT_TYPEHASH = keccak256("Deposit(address FundingPool,address token,uint256 amount,uint256 nonce,uint256 expiry)");

    uint8 internal constant MAX_STAKER_FundingPool_LIST_LENGTH = 32;
    bytes32 internal _DOMAIN_SEPARATOR;
    uint256 internal withdrawalDelayBlocks;
    uint256 internal immutable ORIGINAL_CHAIN_ID;

    IDelegationManager public immutable delegation;
    ISlasher public immutable slasher;

    address public fundingPoolWhitelister;

    mapping(address => uint256) public nonces;
    mapping(address => mapping(IFundingPoool => uint256)) public stakerFundingPoolShares;
    mapping(address => IFundingPoool[]) public stakerFundingPoolList;
    mapping(bytes32 => bool) public withdrawalRootPending;
    mapping(address => uint256) internal numWithdrawalsQueued;
    mapping(IFundingPoool => bool) public fundingPoolIsWhitelistedForDeposit;
    mapping(address => uint256) internal beaconChainETHSharesToDecrementOnWithdrawal;

    modifier onlyFundingPoolWhitelister() {
        require(
            msg.sender == FundingPoolWhitelister,
            "FundingPoolManager.onlyFundingPoolWhitelister: not the FundingPoolWhitelister"
        );
        _;
    }

    modifier onlyFundingPoolsWhitelistedForDeposit(IFundingPoool FundingPool) {
        require(
            FundingPoolIsWhitelistedForDeposit[FundingPool],
            "FundingPoolManager.onlyFundingPoolsWhitelistedForDeposit: FundingPool not whitelisted"
        );
        _;
    }

    modifier onlyDelegationManager() {
        require(msg.sender == address(delegation), "FundingPoolManager.onlyDelegationManager: not the DelegationManager");
        _;
    }

    constructor(
        IDelegationManager _delegation,
        ISlasher _slasher
    ) FundingPoolManagerStorage(_delegation, _slasher) {
        delegation = _delegation;
        slasher = _slasher;
        _disableInitializers();
        ORIGINAL_CHAIN_ID = block.chainid;
    }

    function initialize(
        address initialOwner,
        address initialFundingPoolWhitelister,
        IPauserRegistry _pauserRegistry,
        uint256 initialPausedStatus
    ) external initializer {
        _DOMAIN_SEPARATOR = _calculateDomainSeparator();
        _initializePauser(_pauserRegistry, initialPausedStatus);
        _transferOwnership(initialOwner);
        _setFundingPoolWhitelister(initialFundingPoolWhitelister);
    }

    receive() external payable {
        depositIntoFundingPool(0, address(0), msg.value);
    }

    function depositIntoFundingPool(
        IFundingPoool FundingPool,
        IERC20 token,
        uint256 amount
    ) external payable onlyWhenNotPaused(PAUSED_DEPOSITS) nonReentrant returns (uint256 shares) {
        shares = _depositIntoFundingPool(msg.sender, FundingPool, token, amount);
    }

    function depositIntoFundingPoolWithSignature(
        IFundingPoool FundingPool,
        IERC20 token,
        uint256 amount,
        address staker,
        uint256 expiry,
        bytes memory signature
    ) external onlyWhenNotPaused(PAUSED_DEPOSITS) nonReentrant returns (uint256 shares) {
        require(expiry >= block.timestamp, "FundingPoolManager.depositIntoFundingPoolWithSignature: signature expired");

        uint256 nonce = nonces[staker];
        bytes32 structHash = keccak256(abi.encode(DEPOSIT_TYPEHASH, FundingPool, token, amount, nonce, expiry));
        unchecked {
            nonces[staker] = nonce + 1;
        }

        bytes32 digestHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator(), structHash));

        EIP1271SignatureUtils.checkSignature_EIP1271(staker, digestHash, signature);

        shares = _depositIntoFundingPool(staker, FundingPool, token, amount);
    }

    function removeShares(
        address staker,
        IFundingPoool FundingPool,
        uint256 shares
    ) external onlyDelegationManager {
        _removeShares(staker, FundingPool, shares);
    }

    function addShares(
        address staker,
        IFundingPoool FundingPool,
        uint256 shares
    ) external onlyDelegationManager {
        _addShares(staker, FundingPool, shares);
    }

    function withdrawSharesAsTokens(
        address recipient,
        IFundingPoool FundingPool,
        uint256 shares,
        IERC20 token
    ) external onlyDelegationManager {
        FundingPool.withdraw(recipient, token, shares);
    }

    function migrateQueuedWithdrawal(DeprecatedStruct_QueuedWithdrawal memory queuedWithdrawal) external onlyDelegationManager returns(bool, bytes32) {
        bytes32 existingWithdrawalRoot = calculateWithdrawalRoot(queuedWithdrawal);
        bool isDeleted;

        if (withdrawalRootPending[existingWithdrawalRoot]) {
            withdrawalRootPending[existingWithdrawalRoot] = false;
            isDeleted = true;
        }
        return (isDeleted, existingWithdrawalRoot);
    }

    function setFundingPoolWhitelister(address newFundingPoolWhitelister) external onlyOwner {
        _setFundingPoolWhitelister(newFundingPoolWhitelister);
    }

    function addFundingPoolsToDepositWhitelist(
        IFundingPoool[] calldata FundingPoolsToWhitelist
    ) external onlyFundingPoolWhitelister {
        uint256 FundingPoolsToWhitelistLength = FundingPoolsToWhitelist.length;
        for (uint256 i = 0; i < FundingPoolsToWhitelistLength; ) {

            if (!FundingPoolIsWhitelistedForDeposit[FundingPoolsToWhitelist[i]]) {
                FundingPoolIsWhitelistedForDeposit[FundingPoolsToWhitelist[i]] = true;
                emit FundingPoolAddedToDepositWhitelist(FundingPoolsToWhitelist[i]);
            }
            unchecked {
                ++i;
            }
        }
    }

    function removeFundingPoolsFromDepositWhitelist(
        IFundingPoool[] calldata FundingPoolsToRemoveFromWhitelist
    ) external onlyFundingPoolWhitelister {
        uint256 FundingPoolsToRemoveFromWhitelistLength = FundingPoolsToRemoveFromWhitelist.length;
        for (uint256 i = 0; i < FundingPoolsToRemoveFromWhitelistLength; ) {

            if (FundingPoolIsWhitelistedForDeposit[FundingPoolsToRemoveFromWhitelist[i]]) {
                FundingPoolIsWhitelistedForDeposit[FundingPoolsToRemoveFromWhitelist[i]] = false;
                emit FundingPoolRemovedFromDepositWhitelist(FundingPoolsToRemoveFromWhitelist[i]);
            }
            unchecked {
                ++i;
            }
        }
    }


    function _addShares(address staker, IFundingPoool FundingPool, uint256 shares) internal {
        require(staker != address(0), "FundingPoolManager._addShares: staker cannot be zero address");
        require(shares != 0, "FundingPoolManager._addShares: shares should not be zero!");

        if (stakerFundingPoolShares[staker][FundingPool] == 0) {
            require(
                stakerFundingPoolList[staker].length < MAX_STAKER_FundingPool_LIST_LENGTH,
                "FundingPoolManager._addShares: deposit would exceed MAX_STAKER_FundingPool_LIST_LENGTH"
            );
            stakerFundingPoolList[staker].push(FundingPool);
        }

        stakerFundingPoolShares[staker][FundingPool] += shares;
    }

    function _depositIntoFundingPool(
        address staker,
        IFundingPoool FundingPool,
        IERC20 token,
        uint256 amount
    ) internal onlyFundingPoolsWhitelistedForDeposit(FundingPool) returns (uint256 shares) {

        token.safeTransferFrom(msg.sender, address(FundingPool), amount);

        shares = FundingPool.deposit(token, amount);

        _addShares(staker, FundingPool, shares);

        delegation.increaseDelegatedShares(staker, FundingPool, shares);

        emit Deposit(staker, token, FundingPool, shares);

        return shares;
    }

    function _removeShares(
        address staker,
        IFundingPoool FundingPool,
        uint256 shareAmount
    ) internal returns (bool) {
        require(shareAmount != 0, "FundingPoolManager._removeShares: shareAmount should not be zero!");

        uint256 userShares = stakerFundingPoolShares[staker][FundingPool];

        require(shareAmount <= userShares, "FundingPoolManager._removeShares: shareAmount too high");
        unchecked {
            userShares = userShares - shareAmount;
        }

        stakerFundingPoolShares[staker][FundingPool] = userShares;

        if (userShares == 0) {
            _removeFundingPoolFromStakerFundingPoolList(staker, FundingPool);
            return true;
        }
        return false;
    }

    function _removeFundingPoolFromStakerFundingPoolList(
        address staker,
        IFundingPoool FundingPool
    ) internal {
        uint256 stratsLength = stakerFundingPoolList[staker].length;
        uint256 j = 0;
        for (; j < stratsLength; ) {
            if (stakerFundingPoolList[staker][j] == FundingPool) {
                stakerFundingPoolList[staker][j] = stakerFundingPoolList[staker][
                    stakerFundingPoolList[staker].length - 1
                ];
                break;
            }
            unchecked { ++j; }
        }
        require(j != stratsLength, "FundingPoolManager._removeFundingPoolFromStakerFundingPoolList: FundingPool not found");
        stakerFundingPoolList[staker].pop();
    }

    function _setFundingPoolWhitelister(address newFundingPoolWhitelister) internal {
        emit FundingPoolWhitelisterChanged(FundingPoolWhitelister, newFundingPoolWhitelister);
        FundingPoolWhitelister = newFundingPoolWhitelister;
    }

    function getDeposits(address staker) external view returns (IFundingPoool[] memory, uint256[] memory) {
        uint256 FundingPoolsLength = stakerFundingPoolList[staker].length;
        uint256[] memory shares = new uint256[](FundingPoolsLength);

        for (uint256 i = 0; i < FundingPoolsLength; ) {
            shares[i] = stakerFundingPoolShares[staker][stakerFundingPoolList[staker][i]];
            unchecked {
                ++i;
            }
        }
        return (stakerFundingPoolList[staker], shares);
    }

    function stakerFundingPoolListLength(address staker) external view returns (uint256) {
        return stakerFundingPoolList[staker].length;
    }

    function domainSeparator() public view returns (bytes32) {
        if (block.chainid == ORIGINAL_CHAIN_ID) {
            return _DOMAIN_SEPARATOR;
        } else {
            return _calculateDomainSeparator();
        }
    }

    function _calculateDomainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes("EigenLayer")), block.chainid, address(this)));
    }

    function calculateWithdrawalRoot(DeprecatedStruct_QueuedWithdrawal memory queuedWithdrawal) public pure returns (bytes32) {
        return (
            keccak256(
                abi.encode(
                    queuedWithdrawal.fundingPools,
                    queuedWithdrawal.shares,
                    queuedWithdrawal.staker,
                    queuedWithdrawal.withdrawerAndNonce,
                    queuedWithdrawal.withdrawalStartBlock,
                    queuedWithdrawal.delegatedAddress
                )
            )
        );
    }
}
