// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

interface IDepositContract {
    event DepositEvent(bytes pubkey, bytes withdrawal_credentials, bytes amount, bytes signature, bytes index);

    function deposit(
        bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root
    ) external payable;


    function get_deposit_root() external view returns (bytes32);

    function get_deposit_count() external view returns (bytes memory);
}

interface ERC165 {
    function supportsInterface(bytes4 interfaceId) external pure returns (bool);
}
