// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
//import "forge-std/Test.sol";
//import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
//import "@/contracts/L1/core/Dapplink.sol";
//import "@/contracts/L1/core/StakingRouter.sol";
//import "@/contracts/L1/core/DepositSecurityModule.sol";
//import "@/contracts/L1/core/DapplinkLocator.sol";
//import "@/contracts/L1/core/NodeOperatorsRegistry.sol";
//import "@/contracts/L1/core/WithdrawalVault.sol";
//import "@/contracts/proxy/Proxy.sol";
//
//
//// 定义与 Dapplink 合约相匹配的接口
//interface IDapplinkT {
//    function grantRole(bytes32 role, address account) external;
//    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
//    function setLocator(address _locator) external;
//    function initialize(address _admin) external;
//    // 添加其他必要的函数声明
//}
//contract L1Deployer is Test {
//ProxyAdmin public proxyAdmin;
//    Dapplink dapplink;
//    StakingRouter stakingRouter;
//    DepositSecurityModule depositSecurityModule;
//    DapplinkLocator dapplinkLocator;
//    NodeOperatorsRegistry nodeOperatorsRegistry;
//    WithdrawalVault withdrawalVault;
//    address admin;
//    address _depositContract;
//    address bridgel1;
//    bytes32 _withdrawalCredentials;
//    Proxy proxyDapplink;
//    Proxy proxyStakingRouter;
//    Proxy proxyNodeOperatorsRegistry;
//    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
//    fallback() external payable {}
//    receive() external payable {}
//    function setUp() public {
//        admin = address(this);
//        _depositContract = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
//        bridgel1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
//        _withdrawalCredentials = 0x01000000000000000000000089a65b936290915158ac4a2d66f77c961dfac685;
//
//        dapplink = new Dapplink();
//        proxyDapplink = new Proxy(address(dapplink), admin, "");
//
//        IDapplinkT(address(proxyDapplink)).initialize(admin);
//        // IDapplinkT(address(proxyDapplink)).grantRole(DEFAULT_ADMIN_ROLE, admin);
//
//
//        stakingRouter = new StakingRouter(_depositContract);
//        proxyStakingRouter = new Proxy(address(stakingRouter), admin, "");
//
//        StakingRouter(address(proxyStakingRouter)).initialize(admin, _withdrawalCredentials);
//        StakingRouter(address(proxyStakingRouter)).grantRole(stakingRouter.STAKING_MODULE_MANAGE_ROLE(), admin);
//
//        depositSecurityModule = new DepositSecurityModule(address(proxyDapplink), _depositContract, address(proxyStakingRouter), 150, 25, 6646);
//
//
//        nodeOperatorsRegistry = new NodeOperatorsRegistry();
//        proxyNodeOperatorsRegistry = new Proxy(address(nodeOperatorsRegistry), admin, "");
//
//        NodeOperatorsRegistry(address(proxyNodeOperatorsRegistry)).initialize(admin, 432000 );
//
//        withdrawalVault = new WithdrawalVault(address(proxyDapplink));
//
//
//
//        // 部署合约并初始化配置
//        DapplinkLocator.Config memory initialConfig = DapplinkLocator.Config({
//            l1Bridge: bridgel1, // 替换为您的实际地址
//            dapplink: address(proxyDapplink),
//            stakingRouter: address(proxyStakingRouter),
//            depositSecurityModule: _depositContract,
//            withdrawalVault:address(withdrawalVault)
//        });
//
//
//        dapplinkLocator = new DapplinkLocator(initialConfig);
//        IDapplinkT(address(proxyDapplink)).setLocator(address(dapplinkLocator));
//        StakingRouter(address(proxyStakingRouter)).setLocator(address(dapplinkLocator));
//
//    }
//
//    function test_StakingEth()public{
//        address sender = address(this);
//        vm.deal(sender, 1000 ether); // 为测试账户提供以太
//        vm.prank(sender);
//
//        // 向另一个合约发送以太币
//        (bool success, ) = address(proxyDapplink).call{value: 32 ether}("");
//        require(success, "Transfer failed.");
//        assert(address(proxyDapplink).balance == 32 ether);
//    }
//
//    function test_AddStakingModule()public{
//        StakingRouter(address(proxyStakingRouter)).addStakingModule("test-1", address(proxyNodeOperatorsRegistry),10000, 500, 500);
//        StakingRouter.StakingModule memory stakingModule = StakingRouter(address(proxyStakingRouter)).getStakingModule(1);
//
//        assert(stakingModule.targetShare == 10000);
//    }
//}