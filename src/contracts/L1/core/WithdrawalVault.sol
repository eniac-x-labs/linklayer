// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;


interface IDapplink {
    /**
     * @notice A payable function supposed to be called only by WithdrawalVault contract
     * @dev We need a dedicated function because funds received by the default payable function
     * are treated as a user deposit
     */
    function receiveWithdrawals() external payable;
}

/**
 * @title A vault for temporary storage of withdrawals
 */
contract WithdrawalVault  {

    IDapplink public immutable dappLink;


    // Errors
    error ZeroAddress();
    error NotDappLink();
    error NotEnoughEther(uint256 requested, uint256 balance);
    error ZeroAmount();

    /**
     * @param _dapplink the DappLink token address
     */
    constructor(address _dapplink) {
        if (_dapplink == address(0)) {
            revert ZeroAddress();
        }

        dappLink = IDapplink(_dapplink);
    }

    /**
     * @notice Initialize the contract explicitly.
     * Sets the contract version to '1'.
     */
    function initialize() external {
    }

    /**
     * @notice Withdraw `_amount` of accumulated withdrawals to DappLink contract
     * @dev Can be called only by the DappLink contract
     * @param _amount amount of ETH to withdraw
     */
    function withdrawWithdrawals(uint256 _amount) external {
        if (msg.sender != address(dappLink)) {
            revert NotDappLink();
        }
        if (_amount == 0) {
            revert ZeroAmount();
        }

        uint256 balance = address(this).balance;
        if (_amount > balance) {
            revert NotEnoughEther(_amount, balance);
        }

        dappLink.receiveWithdrawals{value: _amount}();
    }

}