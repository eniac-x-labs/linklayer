## layer3-privacy-contracts

- This staking protocol will be used for layer3 tokenenomics;
- After operator or staker stake their layer two eth(WETH) on our system, they will get staking tickets, our system staking reward and layer one Eth staking reward;
- Reverse staking flow:  
  - Operator or staker stake their layer two eth(WETH) on our system;
  - When staking eth reaches 32, we will withdraw 32 ETH to layer one, and staking 32 ETH to layer one validator;
  - On layer two, when operators save batch data, the staker will get a reward from layer 3 network;
  - On layer one,  stakers will get rewards from the ethereum network;
  - And stakers can get staking tickets from layer two. Any app docking our system must have tickets; Stakers can transfer those tickets to other third party projects to get income.

### 1.Build

```shell
forge build
```

### 2.Test

```shell
forge test
```

### 4.Deploy

```shell
forge script script/Deployer.s.sol:TreasureDeployer --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv
```

### 5. Summary

For this staking protocol. Stakers who can get third rewards from our ecosystem, the first is layer1 eth staking rewards from beacon chain validator, the second is layer2 reward from shadow-x  economics incentives. And the third is staking tickets. The function of staking tickets is that any social dapps dock our layer3 network needs it.

Because staker staking and claim reward on layer2, the transaction fee is cheaper than layer1. I think this can attract users to enter our protocol by staking their eth and weth.

And in this protocol, if operators are evil, stakers will be slashed. Thus, stakes who delegate their vote weight to operators stand for them believe the operators.

