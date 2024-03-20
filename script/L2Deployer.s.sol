// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "@/contracts/L2/core/DelegationManager.sol";
import "@/contracts/L2/core/L1RewardManager.sol";
import "@/contracts/L2/core/L2RewardManager.sol";
import "@/contracts/L2/core/StrategyManager.sol";
import "@/contracts/L2/strategies/StrategyBase.sol";

import "@/contracts/L2/core/SlashManager.sol";

import "@/contracts/access/PauserRegistry.sol";

import "@/test/mocks/EmptyContract.sol";

import "forge-std/Script.sol";



// forge script script/L2Deployer.s.sol:L2Deployer --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv
contract L2Deployer is Script {
    ProxyAdmin public dappLinkProxyAdmin;

    DelegationManager public delegationManager;
    L1RewardManager public l1RewardManager;
    L2RewardManager public l2RewardManager;
    StrategyManager public strategyManager;
    StrategyBase    public socialStrategy;
    StrategyBase    public gamingStrategy;
    StrategyBase    public daStrategy;
    SlashManager    public slasher;

    EmptyContract public emptyContract;
    IPauserRegistry public dappLinkPauserReg;
    address[] pausers;

    function run() external {
        vm.startBroadcast();

        pausers.push(msg.sender);
        address unpauser = msg.sender;
        address dappLinkMultisig = msg.sender;

        dappLinkProxyAdmin = new ProxyAdmin(msg.sender);
        dappLinkPauserReg = new PauserRegistry(pausers, unpauser);

        emptyContract = new EmptyContract();


        uint256 initialPausedStatus = 0;


        delegationManager = DelegationManager(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(dappLinkProxyAdmin), ""))
        );

        slasher = SlashManager(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(dappLinkProxyAdmin), ""))
        );

        l1RewardManager = L1RewardManager(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(dappLinkProxyAdmin), ""))
        );

        l2RewardManager = L2RewardManager(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(dappLinkProxyAdmin), ""))
        );

        strategyManager = StrategyManager(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(dappLinkProxyAdmin), ""))
        );

        socialStrategy = StrategyBase(
           address(new TransparentUpgradeableProxy(address(emptyContract), address(dappLinkProxyAdmin), ""))
        );


        DelegationManager delegationImplementation = new DelegationManager(strategyManager, slasher);
        SlashManager slasherImplementation = new SlashManager(strategyManager, delegationManager);
        L1RewardManager l1RewardManagerImplementation = new L1RewardManager(strategyManager);
        L2RewardManager l2RewardManagerImplementation = new L2RewardManager();
        StrategyManager strategyManagerImplementation = new StrategyManager(delegationManager, slasher);
        StrategyBase socialStrategyImplementation = new StrategyBase(strategyManager);

//        dappLinkProxyAdmin.upgradeAndCall(
//            ITransparentUpgradeableProxy(payable(address(strategyManager))),
//            address(strategyManagerImplementation),
//            abi.encodeWithSelector(
//                StrategyManager.initialize.selector,
//                msg.sender,
//                dappLinkPauserReg,
//                initialPausedStatus
//            )
//        );


//        dappLinkProxyAdmin.upgradeAndCall(
//            ITransparentUpgradeableProxy(payable(address(socialStrategy))),
//            address(socialStrategyImplementation),
//            abi.encodeWithSelector(
//                StrategyBase.initialize.selector,
//                strategyManager
//            )
//        );

//        IStrategy[] storage strategies = [IStrategy(socialStrategy)];
//        uint256[] storage withdrawalDelayBlocks = [100];
//
//         dappLinkProxyAdmin.upgradeAndCall(
//            ITransparentUpgradeableProxy(payable(address(delegationManager))),
//            address(delegationImplementation),
//            abi.encodeWithSelector(
//                DelegationManager.initialize.selector,
//                dappLinkPauserReg,
//                dappLinkMultisig,
//                strategies,
//                withdrawalDelayBlocks
//            )
//        );

//        dappLinkProxyAdmin.upgradeAndCall(
//            ITransparentUpgradeableProxy(payable(address(slasher))),
//            address(slasherImplementation),
//            abi.encodeWithSelector(SlashManager.initialize.selector, msg.sender, dappLinkMultisig)
//        );
//        dappLinkProxyAdmin.upgradeAndCall(
//            ITransparentUpgradeableProxy(payable(address(l1RewardManager))),
//            address(l1RewardManagerImplementation),
//            abi.encodeWithSelector(L1RewardManager.initialize.selector, dappLinkPauserReg, dappLinkMultisig)
//        );
//
//         dappLinkProxyAdmin.upgradeAndCall(
//            ITransparentUpgradeableProxy(payable(address(l2RewardManager))),
//            address(l2RewardManagerImplementation),
//            abi.encodeWithSelector(L2RewardManager.initialize.selector, dappLinkPauserReg, dappLinkMultisig)
//        );
//
//        dappLinkProxyAdmin.upgradeAndCall(
//            ITransparentUpgradeableProxy(payable(address(strategyManager))),
//            address(strategyManagerImplementation),
//            abi.encodeWithSelector(StrategyManager.initialize.selector, msg.sender, dappLinkMultisig)
//        );

 //       vm.writeFile("data/delegationManager.addr", vm.toString(address(delegationManager)));
//        vm.writeFile("data/slasher.addr", vm.toString(address(slasher)));
//        vm.writeFile("data/l1RewardManager.addr", vm.toString(address(l1RewardManager)));
//        vm.writeFile("data/l2RewardManager.addr", vm.toString(address(l2RewardManager)));
//        vm.writeFile("data/strategyManager.addr", vm.toString(address(strategyManager)));

          vm.stopBroadcast();
    }
}