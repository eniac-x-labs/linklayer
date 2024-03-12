// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;


import "@/contracts/libraries/Math256.sol";
import "@/contracts/libraries/UnstructuredStorage.sol";
import "@/contracts/libraries/SafeMath.sol";
import "@/contracts/L1/core/BaseApp.sol";

interface IBridge {
    function BridgeInitiateETH(
        uint256 sourceChainId,
        uint256 destChainId,
        address to
    ) external payable returns (bool);
}
interface IStakingRouter {
    function deposit(
        uint256 _depositsCount,
        uint256 _stakingModuleId,
        bytes memory _depositCalldata
    ) external payable;

    function getStakingRewardsDistribution()
        external
        view
        returns (
            address[] memory recipients,
            uint256[] memory stakingModuleIds,
            uint96[] memory stakingModuleFees,
            uint96 totalFee,
            uint256 precisionPoints
        );

    function getWithdrawalCredentials() external view returns (bytes32);

    function reportRewardsMinted(uint256[] memory _stakingModuleIds, uint256[] memory _totalShares) external;

    function getTotalFeeE4Precision() external view returns (uint16 totalFee);

    function getStakingFeeAggregateDistributionE4Precision() external view returns (
        uint16 modulesFee, uint16 treasuryFee
    );

    function getStakingModuleMaxDepositsCount(uint256 _stakingModuleId, uint256 _maxDepositsValue)
        external
        view
        returns (uint256);

    function TOTAL_BASIS_POINTS() external view returns (uint256);
}

contract Dapplink is BaseApp{
    using SafeMath for uint256;
    using UnstructuredStorage for bytes32;

    /// ACL
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");

    bytes32 public constant WITHDRAWL2_ROLE = keccak256("WITHDRAWL2_ROLE");

    uint256 private constant DEPOSIT_SIZE = 32 ether;
    /// @dev amount of Ether (on the current Ethereum side) buffered on this smart contract balance
    bytes32 internal constant BUFFERED_ETHER_POSITION = keccak256("dapplink.dapplink.bufferedEther");
    bytes32 internal constant DEPOSITED_VALIDATORS_POSITION = keccak256("dapplink.dapplink.depositedValidators");
    //When contract receive ethers
    event EthersReceive(address _transfer, uint256 _amount);
    // Staking was paused (don't accept user's ether submits)
    event StakingPaused();
    // Staking was resumed (accept user's ether submits)
    event StakingResumed();
     // The `amount` of ether was sent to the deposit_contract.deposit function
    event Unbuffered(uint256 amount);
    // Emits when var at `DEPOSITED_VALIDATORS_POSITION` changed
    event DepositedValidatorsChanged(
        uint256 depositedValidators
    );
    /**
     * @dev
     * @param _locator Dapplink's locator
     */
    function initialize(address _locator) public payable initializer {
        __BaseApp_init(_locator);

        grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Send funds to the pool
     * @dev Receive deposits for 2 layers and pushes them to the Ethereum Deposit contract.
     */
    receive() external payable {
        _submit();
    }

    /**
     * @notice Send funds to the pool
     */
    function _submit() internal {
        require(msg.value != 0, "ZERO_DEPOSIT");

        require(msg.value.div(DEPOSIT_SIZE) > 0, "NOT_ENOUGH_ETHERS");

        _setBufferedEther(_getBufferedEther().add(msg.value));

        emit EthersReceive(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw ethers to L2
     * @param _chainId Id of target chain
     * @param _amount Amount of brdige
     * @param _to Address for receiving transfer on the layer 2
     */
    function withdrawL2(uint256 _chainId, uint256 _amount, address _to) external onlyRole(WITHDRAWL2_ROLE) {
        IBridge _brdige = IBridge(locator.l1Bridge());
        bool _result = _brdige.BridgeInitiateETH{value:_amount}(block.chainid, _chainId, _to);

        require(_result, "WITHDRAWL2_ERROR");

    }


    /**
     * @dev Invokes a deposit call to the Staking Router contract and updates buffered counters
     * @param _maxDepositsCount max deposits count
     * @param _stakingModuleId id of the staking module to be deposited
     * @param _depositCalldata module calldata
     */
    function deposit(uint256 _maxDepositsCount, uint256 _stakingModuleId, bytes memory _depositCalldata) external {

        require(msg.sender == locator.depositSecurityModule(), "APP_AUTH_DSM_FAILED");
        // require(canDeposit(), "CAN_NOT_DEPOSIT");

        IStakingRouter stakingRouter = _stakingRouter();
        uint256 depositsCount = Math256.min(
            _maxDepositsCount,
            stakingRouter.getStakingModuleMaxDepositsCount(_stakingModuleId, getDepositableEther())
        );

        uint256 depositsValue;
        if (depositsCount > 0) {
            depositsValue = depositsCount.mul(DEPOSIT_SIZE);
            /// @dev firstly update the local state of the contract to prevent a reentrancy attack,
            ///     even if the StakingRouter is a trusted contract.
            BUFFERED_ETHER_POSITION.setStorageUint256(_getBufferedEther().sub(depositsValue));
            emit Unbuffered(depositsValue);

            uint256 newDepositedValidators = DEPOSITED_VALIDATORS_POSITION.getStorageUint256().add(depositsCount);
            DEPOSITED_VALIDATORS_POSITION.setStorageUint256(newDepositedValidators);
            emit DepositedValidatorsChanged(newDepositedValidators);
        }

        /// @dev transfer ether to StakingRouter and make a deposit at the same time. All the ether
        ///     sent to StakingRouter is counted as deposited. If StakingRouter can't deposit all
        ///     passed ether it MUST revert the whole transaction (never happens in normal circumstances)
        stakingRouter.deposit{value: depositsValue}(depositsCount, _stakingModuleId, _depositCalldata);
    }
     /**
     * @dev Returns depositable ether amount.
     * Takes into account unfinalized stETH required by WithdrawalQueue
     */
    function getDepositableEther() public view returns (uint256) {
        uint256 bufferedEther = _getBufferedEther();
        return bufferedEther;
    }

    /**
     * @dev Check that DappLink allows depositing buffered ether to the consensus layer
     * Depends on the bunker state and protocol's pause state
     */
    // function canDeposit() public view returns (bool) {
    //     return !_withdrawalQueue().isBunkerModeActive() && !isStopped();
    // }

    function _stakingRouter() internal view returns (IStakingRouter) {
        return IStakingRouter(locator.stakingRouter());
    }
    function _setBufferedEther(uint256 _newBufferedEther) internal {
        BUFFERED_ETHER_POSITION.setStorageUint256(_newBufferedEther);
    }

    /**
     * @dev Gets the amount of Ether temporary buffered on this contract balance
     */
    function _getBufferedEther() internal view returns (uint256) {
        return BUFFERED_ETHER_POSITION.getStorageUint256();
    }
}
