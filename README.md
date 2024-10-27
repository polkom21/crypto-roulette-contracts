# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.ts
```

```shell
npx hardhat test --network hardhat
```

## Deploy to amoy

```shell
npx hardhat ignition deploy ignition/modules/RouletteModule.ts --parameters ignition/amoy-params.json --network amoy
```