// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface IDapplinkLocator {
    
    function l1Bridge() external view returns(address);
    function dapplink() external view returns(address);
    function depositSecurityModule() external view returns(address);
    function stakingRouter() external view returns(address);

    function coreComponents() external view returns(
        address l1Bridge,
        address dapplink,
        address depositSecurityModule,
        address stakingRouter
    );
    // function oracleReportComponents() external view returns(
    //     address l1Bridge,
    //     address dapplink
    // );
}