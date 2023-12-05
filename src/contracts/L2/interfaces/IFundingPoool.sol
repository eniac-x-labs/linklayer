// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

interface IFundingPoool {
    function deposit(uint256 amount) external payable returns (uint256);

    function withdraw(address recipient, uint256 amountShares) external payable;

    function sharesToStaking(uint256 amountShares) external returns (uint256);

    function stakingToShares(uint256 amountStaking) external returns (uint256);

    function userStaking(address user) external returns (uint256);

    function shares(address user) external view returns (uint256);

    function sharesToStakingView(uint256 amountShares) external view returns (uint256);

    function stakingToSharesView(uint256 amountStaking) external view returns (uint256);

    function userStakingView(address user) external view returns (uint256);

    function totalShares() external view returns (uint256);

    function explanation() external view returns (string memory);
}
