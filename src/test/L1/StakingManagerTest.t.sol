// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@/test/L1/L1Test.t.sol";
contract StakingManagerTest is L1Test{
    address admin = msg.sender;
    uint256 amount = 32 ether;
    uint128 amount128 = 32 ether;



    function testBatchMintDEth()public{
        vm.startPrank(admin);
        address _shareAddress = DETH(address(proxyDETH)).l2ShareAddress();
        console.log("_shareAddress--------",_shareAddress);
        IDETH.BatchMint memory dm = IDETH.BatchMint({staker:admin,amount:amount});
        IDETH.BatchMint[] memory mints = new IDETH.BatchMint[](1);
        mints[0] = dm;
        DETH(address(proxyDETH)).batchMint(mints);
    }

    function testAllocateETH()public{
   
        vm.startPrank(admin);

        StakingManager(payable(address(proxyStakingManager))).allocateETH(0,amount);

        assert(StakingManager(payable(address(proxyStakingManager))).unallocatedETH() == 0);
    }


    function testStake()public{
        vm.startPrank(admin);
        address dapplinkBridge = 0xD6A7740477dD55d5feD7a5fE81C52eA168CDe3FF; // holesky testne

        // StakingManager(payable(address(proxyStakingManager))).stake{value:32 ether}(32000000000000000000);

        assert(address(proxyStakingManager).balance == 32000000000000000000);
    }


    function testStakingManager()public view{
        address dapplinkBridge = 0xD6A7740477dD55d5feD7a5fE81C52eA168CDe3FF; // holesky testne
        address dBridge = StakingManager(payable(address(proxyStakingManager))).locator().dapplinkBridge();
        assert(dapplinkBridge == dBridge);
    }

    function testUnstakeRequest()public{
   
        vm.startPrank(admin);

        
        uint256 totalControlled = StakingManager(payable(address(proxyStakingManager))).totalControlled();
        console.log("totalControlled========",totalControlled);

        // StakingManager(payable(address(proxyStakingManager))).stake{value:32 ether}(32000000000000000000);
        uint256 totalControlledAfter = StakingManager(payable(address(proxyStakingManager))).totalControlled();
        console.log("totalControlledAfter========",totalControlledAfter);

        IDETH.BatchMint memory dm = IDETH.BatchMint({staker:admin,amount:amount});
        IDETH.BatchMint[] memory mints = new IDETH.BatchMint[](1);
        mints[0] = dm;
        DETH(address(proxyDETH)).batchMint(mints);

        DETH(address(proxyDETH)).approve(address(proxyStakingManager),amount);

        // console.log("create stakemanage-------",address(proxyStakingManager));

        // address stakeAddress = address(UnstakeRequestsManager(payable(address(proxyUnstakeRequestsManager))).stakingContract());
        // console.log("UnstakeRequestsManager-------",stakeAddress);

        StakingManager(payable(address(proxyStakingManager))).unstakeRequest(amount128,amount128,admin,5);

    }


    function testSB()public{
   
        vm.startPrank(admin);

        bool hasr = StakingManager(payable(address(proxyStakingManager))).hasRole(StakingManager(payable(address(proxyStakingManager))).STAKING_ALLOWLIST_ROLE(),admin);

        assert(hasr == true);
    }
} 