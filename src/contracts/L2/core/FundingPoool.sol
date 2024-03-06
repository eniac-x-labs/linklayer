// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IFundingPooolManager.sol";

import "../../access/Pausable.sol";
import "../../libraries/SafeCall.sol";




contract FundingPoool is Initializable, Pausable, IFundingPoool {

    uint8 internal constant PAUSED_DEPOSITS = 0;
    uint8 internal constant PAUSED_WITHDRAWALS = 1;
    uint256 internal constant SHARES_OFFSET = 1e3;
    uint256 internal constant BALANCE_OFFSET = 1e3;

    uint256 public totalShares;

    IFundingPooolManager public immutable foundingPoolManager;

    modifier onlyFundingPooolManager() {
        require(msg.sender == address(foundingPoolManager), "FundingPoool.FundingPooolManager");
        _;
    }

    constructor(IFundingPooolManager _foundingPoolManager) {
        foundingPoolManager = _foundingPoolManager;
        _disableInitializers();
    }

    function initialize(IPauserRegistry _pauserRegistry) public virtual initializer {
        _initializeStrategyBase(_pauserRegistry);
    }

    function _initializeStrategyBase(
        IPauserRegistry _pauserRegistry
    ) internal onlyInitializing {
        _initializePauser(_pauserRegistry, UNPAUSE_ALL);
    }

    function deposit(
        uint256 amount
    ) external payable virtual override onlyWhenNotPaused(PAUSED_DEPOSITS) onlyFundingPooolManager returns (uint256 newShares) {

        _beforeDeposit(amount);


        uint256 priorTotalShares = totalShares;

        uint256 virtualShareAmount = priorTotalShares + SHARES_OFFSET;
        uint256 virtualEthBalance = _ethBalance() + BALANCE_OFFSET;
        uint256 virtualPriorEthBalance = virtualEthBalance - amount;

        newShares = (amount * virtualShareAmount) / virtualPriorEthBalance;

        require(newShares != 0, "FundingPoool.deposit: newShares cannot be zero");

        totalShares = (priorTotalShares + newShares);

        return newShares;
    }

    function withdraw(
        address recipient,
        uint256 amountShares
    ) external virtual override onlyWhenNotPaused(PAUSED_WITHDRAWALS) onlyFundingPooolManager {
        _beforeWithdrawal(recipient, amountShares);

        uint256 priorTotalShares = totalShares;

        require(
            amountShares <= priorTotalShares,
            "FundingPoool.withdraw: amountShares must be less than or equal to totalShares"
        );

        uint256 virtualPriorTotalShares = priorTotalShares + SHARES_OFFSET;
        uint256 virtualEthBalance = _ethBalance() + BALANCE_OFFSET;
        uint256 amountToSend = (virtualEthBalance * amountShares) / virtualPriorTotalShares;

        totalShares = priorTotalShares - amountShares;

        bool success = SafeCall.call(recipient, gasleft(), amountToSend, hex"");
        require(success, "FundingPool: ETH withdraw failed");
    }

    // solhint-disable-next-line no-empty-blocks
    function _beforeDeposit(uint256 amount) internal virtual {}

    // solhint-disable-next-line no-empty-blocks
    function _beforeWithdrawal(address recipient, uint256 amountShares) internal virtual {}

    function explanation() external pure virtual override returns (string memory) {
        return "Base funding pool implementation to inherit from for more complex implementations";
    }

    function sharesToStakingView(uint256 amountShares) public view virtual override returns (uint256) {
        uint256 virtualTotalShares = totalShares + SHARES_OFFSET;
        uint256 virtualEthBalance = _ethBalance() + BALANCE_OFFSET;

        return (virtualEthBalance * amountShares) / virtualTotalShares;
    }

    function sharesToStaking(uint256 amountShares) public view virtual override returns (uint256) {
        return sharesToStakingView(amountShares);
    }

    function stakingToSharesView(uint256 amountStaking) public view virtual returns (uint256) {
        uint256 virtualTotalShares = totalShares + SHARES_OFFSET;
        uint256 virtualEthBalance = _ethBalance() + BALANCE_OFFSET;

        return (amountStaking * virtualTotalShares) / virtualEthBalance;
    }

    function stakingToShares(uint256 amountStaking) external view virtual returns (uint256) {
        return stakingToSharesView(amountStaking);
    }

    function userStakingView(address user) external view virtual returns (uint256) {
        return sharesToStakingView(shares(user));
    }

    function userStaking(address user) external virtual returns (uint256) {
        return sharesToStaking(shares(user));
    }

    function shares(address user) public view virtual returns (uint256) {
        return 10;
        // return foundingPoolManager.stakerStrategyShares(user, IFundingPoool(address(this)));
    }

    // slither-disable-next-line dead-code
    function _ethBalance() internal view virtual returns (uint256) {
        return address(this).balance;
    }

    uint256[48] private __gap;
}
