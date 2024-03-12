// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// import "@/contracts/L1/core/DelegationManager.sol";
// import "@/contracts/L1/core/StrategyManager.sol";
import "@/contracts/access/PauserRegistry.sol";

import "@/test/mocks/EmptyContract.sol";

import "forge-std/Script.sol";


// forge script script/L1Deployer.s.sol:TreasureDeployer --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv
contract PrivacyContractsDeployer is Script {
    ProxyAdmin public savourTsProxyAdmin;
    // DelegationManager public delegation;
    // StrategyManager public strategy;
    EmptyContract public emptyContract;
    PauserRegistry public savourPcPauserReg;
    address[] pausers;

    function run() external {
        vm.startBroadcast();
        pausers.push(msg.sender);
        address unpauser = msg.sender;
        address savourTsReputedMultisig = msg.sender;

        savourTsProxyAdmin = new ProxyAdmin(savourTsReputedMultisig);
        savourPcPauserReg = new PauserRegistry(pausers, unpauser);

        emptyContract = new EmptyContract();

        // delegation = DelegationManager(
        //     address(new TransparentUpgradeableProxy(address(emptyContract), address(savourTsProxyAdmin), "")
        //     )
        // );

        // DelegationManager delegationImplementation = new DelegationManager();

        // vm.writeFile("data/delegation.addr", vm.toString(address(delegation)));
        // vm.writeFile("data/delegationImplementation.addr", vm.toString(address(delegationImplementation)));

        vm.stopBroadcast();
    }
}