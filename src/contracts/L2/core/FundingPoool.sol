// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "../interfaces/IFundingPooolManager.sol";
import "../access/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";


contract FundingPoool is Initializable, Pausable, IFundingPoool {
    using SafeERC20 for IERC20;

    uint8 internal constant PAUSED_DEPOSITS = 0;
    uint8 internal constant PAUSED_WITHDRAWALS = 1;
    uint256 internal constant SHARES_OFFSET = 1e3;
    uint256 internal constant BALANCE_OFFSET = 1e3;

    uint256 public totalShares;

    IFundingPooolManager public immutable foundingPoolManager;
    IERC20 public stakingToken;

    modifier onlyFundingPooolManager() {
        require(msg.sender == address(foundingPoolManager), "FundingPoool.FundingPooolManager");
        _;
    }

    constructor(IFundingPooolManager _foundingPoolManager) {
        foundingPoolManager = _foundingPoolManager;
        _disableInitializers();
    }

    function initialize(IERC20 _stakingToken, IPauserRegistry _pauserRegistry) public virtual initializer {
        _initializeStrategyBase(_stakingToken, _pauserRegistry);
    }

    function _initializeStrategyBase(
        IERC20 _stakingToken,
        IPauserRegistry _pauserRegistry
    ) internal onlyInitializing {
        stakingToken = _stakingToken;
        _initializePauser(_pauserRegistry, UNPAUSE_ALL);
    }

    function deposit(
        IERC20 token,
        uint256 amount
    ) external payable virtual override onlyWhenNotPaused(PAUSED_DEPOSITS) onlyfoundingPoolManager returns (uint256 newShares) {

        _beforeDeposit(token, amount);

        require(token == stakingToken, "FundingPoool.deposit: Can only deposit stakingToken");

        uint256 priorTotalShares = totalShares;

        uint256 virtualShareAmount = priorTotalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = _tokenBalance() + BALANCE_OFFSET;
        uint256 virtualPriorTokenBalance = virtualTokenBalance - amount;

        newShares = (amount * virtualShareAmount) / virtualPriorTokenBalance;

        require(newShares != 0, "FundingPoool.deposit: newShares cannot be zero");

        totalShares = (priorTotalShares + newShares);

        return newShares;
    }

    function withdraw(
        address recipient,
        IERC20 token,
        uint256 amountShares
    ) external virtual override onlyWhenNotPaused(PAUSED_WITHDRAWALS) onlyfoundingPoolManager {
        _beforeWithdrawal(recipient, token, amountShares);

        require(token == stakingToken, "FundingPoool.withdraw: Can only withdraw the strategy token");

        uint256 priorTotalShares = totalShares;

        require(
            amountShares <= priorTotalShares,
            "FundingPoool.withdraw: amountShares must be less than or equal to totalShares"
        );

        uint256 virtualPriorTotalShares = priorTotalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = _tokenBalance() + BALANCE_OFFSET;
        uint256 amountToSend = (virtualTokenBalance * amountShares) / virtualPriorTotalShares;

        totalShares = priorTotalShares - amountShares;

        stakingToken.safeTransfer(recipient, amountToSend);
    }

    // solhint-disable-next-line no-empty-blocks
    function _beforeDeposit(IERC20 token, uint256 amount) internal virtual {}

    // solhint-disable-next-line no-empty-blocks
    function _beforeWithdrawal(address recipient, IERC20 token, uint256 amountShares) internal virtual {}

    function explanation() external pure virtual override returns (string memory) {
        return "Base funding pool implementation to inherit from for more complex implementations";
    }

    function sharesToStakingView(uint256 amountShares) public view virtual override returns (uint256) {
        uint256 virtualTotalShares = totalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = _tokenBalance() + BALANCE_OFFSET;

        return (virtualTokenBalance * amountShares) / virtualTotalShares;
    }

    function sharesToStaking(uint256 amountShares) public view virtual override returns (uint256) {
        return sharesToStakingView(amountShares);
    }

    function stakingToSharesView(uint256 amountStaking) public view virtual returns (uint256) {
        uint256 virtualTotalShares = totalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = _tokenBalance() + BALANCE_OFFSET;

        return (amountStaking * virtualTotalShares) / virtualTokenBalance;
    }

    function stakingToShares(uint256 amountStaking) external view virtual returns (uint256) {
        return StakingToSharesView(amountStaking);
    }

    function userStakingView(address user) external view virtual returns (uint256) {
        return sharesToStakingView(shares(user));
    }

    function userStaking(address user) external virtual returns (uint256) {
        return sharesToStaking(shares(user));
    }

    function shares(address user) public view virtual returns (uint256) {
        return foundingPoolManager.stakerStrategyShares(user, IFundingPoool(address(this)));
    }

    // slither-disable-next-line dead-code
    function _tokenBalance() internal view virtual returns (uint256) {
        return stakingToken.balanceOf(address(this));
    }

    uint256[48] private __gap;
}
