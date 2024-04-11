# linklayer

## Introduction

This linklayer multi-staking protocol;


## How is work


## Directory Structure


## Build

```shell
forge build
```

## Test

```shell
forge test
```

## 4.Deploy

### Deploy L1
```
forge script script/L1Deployer.s.sol:L1Deployer --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv --legacy --gas-price 1000000000
```

### Deploy L2
```
forge script script/L2Deployer.s.sol:L12Deployer --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv --legacy --gas-price 1000000000
```
