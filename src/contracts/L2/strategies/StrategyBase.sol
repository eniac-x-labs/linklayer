// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";

import "../interfaces/IStrategyManager.sol";
import "../../access/interface/IL2Pauser.sol";
import "../../libraries/ETHAddress.sol";
import "../../libraries/SafeCall.sol";




contract StrategyBase is Initializable, IStrategy {
    using SafeERC20 for IERC20;

    uint8 internal constant PAUSED_DEPOSITS = 0;
    uint8 internal constant PAUSED_WITHDRAWALS = 1;

    uint256 internal constant SHARES_OFFSET = 1e3;
    uint256 internal constant BALANCE_OFFSET = 1e3;

    IStrategyManager public strategyManager;

    IERC20 public stakingWeth;

    address public relayer;

    uint256 public totalShares;

    IL2Pauser public pauser;

    modifier onlyStrategyManager() {
        require(msg.sender == address(strategyManager), "StrategyBase.onlyStrategyManager");
        _;
    }

    modifier onlyRelayer() {
        require(msg.sender == relayer, "StrategyBase.onlyRelayer");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        IERC20 _stakingWeth,
        address  _relayer,
        IStrategyManager _strategyManager,
        IL2Pauser _pauser
    ) public virtual initializer {
        _initializeStrategyBase(_stakingWeth, _pauser);
        strategyManager = _strategyManager;
        relayer = _relayer;
    }

    function _initializeStrategyBase(
        IERC20 _stakingWeth,
        IL2Pauser _pauser
    ) internal onlyInitializing {
        stakingWeth = _stakingWeth;
        pauser = _pauser;
    }

    function deposit(
        IERC20 weth,
        uint256 amount
    ) external virtual override onlyStrategyManager returns (uint256 newShares) {

        require(pauser.isStrategyDeposit(), "StrategyBase:deposit paused");

        _beforeDeposit(weth);

        uint256 priorTotalShares = totalShares;

        uint256 virtualShareAmount = priorTotalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = ethWethBalance() + BALANCE_OFFSET;

        uint256 virtualPriorTokenBalance = virtualTokenBalance - amount;
        newShares = (amount * virtualShareAmount) / virtualPriorTokenBalance;

        require(newShares != 0, "StrategyBase.deposit: newShares cannot be zero");

        totalShares = (priorTotalShares + newShares);
        return newShares;
    }

    function withdraw(
        address recipient,
        IERC20 weth,
        uint256 amountShares
    ) external virtual override onlyStrategyManager {
        require(pauser.isStrategyWithdraw(), "StrategyBase:withdraw paused");

        _beforeWithdrawal(weth);

        uint256 priorTotalShares = totalShares;

        require(
            amountShares <= priorTotalShares,
            "StrategyBase.withdraw: amountShares must be less than or equal to totalShares"
        );

        uint256 virtualPriorTotalShares = priorTotalShares + SHARES_OFFSET;

        uint256 virtualTokenBalance = ethWethBalance() + BALANCE_OFFSET;

        uint256 amountToSend = (virtualTokenBalance * amountShares) / virtualPriorTotalShares;

        totalShares = priorTotalShares - amountShares;

        _afterWithdrawal(recipient, weth, amountToSend);
    }

    function _beforeDeposit(IERC20 weth) internal virtual {
        require(weth == stakingWeth || address(weth) == ETHAddress.EthAddress, "StrategyBase.deposit: Can only deposit stakingWeth and eth");
    }


    function _beforeWithdrawal(IERC20 weth) internal virtual {
        require(weth == stakingWeth || address(weth) == ETHAddress.EthAddress, "StrategyBase.withdraw: Can only withdraw the strategy weth and eth");
    }


    function _afterWithdrawal(address recipient, IERC20 weth, uint256 amountToSend) internal virtual {
        if (address(weth) == ETHAddress.EthAddress) {
             payable(recipient).transfer(amountToSend);
        } else {
             weth.safeTransfer(recipient, amountToSend);
        }
    }

    function explanation() external pure virtual override returns (string memory) {
        return "Base Strategy implementation to inherit from for more complex implementations";
    }

    function sharesToStakingView(uint256 amountShares) public view virtual override returns (uint256) {
        uint256 virtualTotalShares = totalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = ethWethBalance() + BALANCE_OFFSET;
        return (virtualTokenBalance * amountShares) / virtualTotalShares;
    }

    function sharesToStaking(uint256 amountShares) public view virtual override returns (uint256) {
        return sharesToStakingView(amountShares);
    }

    function stakingToSharesView(uint256 amountStaking) public view virtual returns (uint256) {

        uint256 virtualTotalShares = totalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = ethWethBalance() + BALANCE_OFFSET;

        return (amountStaking * virtualTotalShares) / virtualTokenBalance;
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
        return strategyManager.stakerStrategyShares(user, IStrategy(address(this)));
    }

    function ethWethBalance() internal view virtual returns (uint256) {
        return stakingWeth.balanceOf(address(this)) + address(this).balance;
    }

    function ETHBalance() external view virtual returns (uint256) {
        return address(this).balance;
    }

    function WETHBalance() external view virtual returns (uint256) {
        return stakingWeth.balanceOf(address(this));
    }

    function transferETHToL2DappLinkBridge(uint256 sourceChainId, uint256 destChainId, address bridge, address l1StakingManagerAddr, uint256 gasLimit) external payable onlyRelayer returns (bool) {
        if (stakingWeth.balanceOf(address(this)) >= 32e18 ) {
            uint256 amountBridge = (stakingWeth.balanceOf(address(this)) / 32e18) * 32e18;
            bool success = SafeCall.callWithMinGas(
                bridge,
                gasLimit,
                amountBridge,
                abi.encodeWithSignature("BridgeInitiateETH(uint256,uint256,to)", sourceChainId, destChainId, l1StakingManagerAddr)
            );
            return success;
        }
        return false;
    }

    function transferWETHToL2DappLinkBridge(uint256 sourceChainId, uint256 destChainId, address bridge, address l1StakingManagerAddr, address wethAddress, uint256 gasLimit) external payable onlyRelayer returns (bool) {
         if (address(this).balance > 32e18) {
             uint256 amountBridge = ((address(this).balance) / 32e18) * 32e18;
             bool success = SafeCall.callWithMinGas(
                bridge,
                gasLimit,
                msg.value,
                abi.encodeWithSignature("BridgeInitiateERC20(uint256,uint256,to,value)", sourceChainId, destChainId, l1StakingManagerAddr, wethAddress, amountBridge)
            );
            return success;
        }
        return false;
    }


    uint256[48] private __gap;
}
