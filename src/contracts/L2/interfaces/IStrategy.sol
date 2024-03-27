// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IStrategy {
    function deposit(IERC20 weth, uint256 amount) external returns (uint256);

    function withdraw(address recipient, IERC20 weth, uint256 amountShares) external;

    function sharesToStaking(uint256 amountShares) external returns (uint256);

    function stakingToShares(uint256 amountStaking) external returns (uint256);

    function userStaking(address user) external returns (uint256);

    function shares(address user) external view returns (uint256);

    function sharesToStakingView(uint256 amountShares) external view returns (uint256);

    function stakingToSharesView(uint256 amountStaking) external view returns (uint256);

    function userStakingView(address user) external view returns (uint256);

    function stakingWeth() external view returns (IERC20);

    function totalShares() external view returns (uint256);

    function explanation() external view returns (string memory);

    function transferWETHToL2DappLinkBridge(uint256 sourceChainId, uint256 destChainId, address bridge, address l1StakingManagerAddr, address wethAddress, uint256 gasLimit) external payable returns (bool);

    function transferETHToL2DappLinkBridge(uint256 sourceChainId, uint256 destChainId, address bridge, address l1StakingManagerAddr, uint256 gasLimit) external payable returns (bool);

    function ETHBalance() external view returns (uint256);

    function WETHBalance() external view returns (uint256);

}
