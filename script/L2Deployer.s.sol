// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../src/contracts/L1/core/TreasureManager.sol";
import "../src/contracts/access/PauserRegistry.sol";

import "../src/test/mocks/EmptyContract.sol";

import "forge-std/Script.sol";


// forge script script/L2Deployer.s.sol:TreasureDeployer --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv
contract TreasureDeployer is Script {
    ProxyAdmin public savourTsProxyAdmin;
    TreasureManager public tsManager;
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

        tsManager = TreasureManager(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(savourTsProxyAdmin), "")
            )
        );

        TreasureManager tsManagerImplementation = new TreasureManager();

        vm.writeFile("data/tsManager.addr", vm.toString(address(tsManager)));
        vm.writeFile("data/tsManagerImplementation.addr", vm.toString(address(tsManagerImplementation)));

        vm.stopBroadcast();
    }
}