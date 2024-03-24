// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "forge-std/Script.sol";
import "@/contracts/L1/core/Dapplink.sol";
import "@/contracts/L1/core/StakingRouter.sol";
import "@/contracts/L1/core/DepositSecurityModule.sol";
import "@/contracts/L1/core/DapplinkLocator.sol";
import "@/contracts/proxy/Proxy.sol";




// 定义与 Dapplink 合约相匹配的接口
interface IDapplinkT {
    function grantRole(bytes32 role, address account) external;
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function setLocator(address _locator) external;
    function initialize(address _admin) external;
    // 添加其他必要的函数声明
}

// forge script script/L1Deployer.s.sol:PrivacyContractsDeployer --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv
// forge script ./script/L1Deployer.s.sol:PrivacyContractsDeployer --rpc-url http://localhost:8545  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast -vvvv
// start local node of fork ethereum mainnet : anvil --fork-url https://mainnet.infura.io/v3/2004cc47a4cc47c69e8375ec0506a39f
contract PrivacyContractsDeployer is Script {
    ProxyAdmin public proxyAdmin;
    Dapplink dapplink;
    StakingRouter stakingRouter;
    DepositSecurityModule depositSecurityModule;
    DapplinkLocator dapplinkLocator;
    address admin;
    address _depositContract;
    address bridgel1;
    bytes32 _withdrawalCredentials;
    Proxy proxyDapplink;
    Proxy proxyStakingRouter;
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    function setUp() public {
        admin = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        _depositContract = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
        bridgel1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        _withdrawalCredentials = 0x01000000000000000000000089a65b936290915158ac4a2d66f77c961dfac685;
    }
    function run() external {
        // vm.startBroadcast(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

        // dapplink = new Dapplink();
        // proxyDapplink = new Proxy(address(dapplink), admin, "");
        
        // IDapplinkT(address(proxyDapplink)).initialize(admin);
        // // IDapplinkT(address(proxyDapplink)).grantRole(DEFAULT_ADMIN_ROLE, admin);


        // stakingRouter = new StakingRouter(_depositContract);
        // proxyStakingRouter = new Proxy(address(stakingRouter), admin, "");
        
        // StakingRouter(address(proxyStakingRouter)).initialize(admin, _withdrawalCredentials);
        // // StakingRouter(address(proxyStakingRouter)).grantRole(DEFAULT_ADMIN_ROLE, admin);

        // depositSecurityModule = new DepositSecurityModule(address(proxyDapplink), _depositContract, address(proxyStakingRouter), 150, 25, 6646);




        // // 部署合约并初始化配置
        // DapplinkLocator.Config memory initialConfig = DapplinkLocator.Config({
        //     l1Bridge: bridgel1, // 替换为您的实际地址
        //     dapplink: address(proxyDapplink),
        //     stakingRouter: address(proxyStakingRouter),
        //     depositSecurityModule: _depositContract
        // });


        // dapplinkLocator = new DapplinkLocator(initialConfig);
        // IDapplinkT(address(proxyDapplink)).setLocator(address(dapplinkLocator));
        // StakingRouter(address(proxyStakingRouter)).setLocator(address(dapplinkLocator));

        // vm.stopBroadcast();
    }
}