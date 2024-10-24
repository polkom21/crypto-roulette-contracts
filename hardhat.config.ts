import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-contract-sizer";

const config: HardhatUserConfig = {
  solidity: "0.8.27",
  contractSizer: {
    runOnCompile: true,
  },
};

export default config;
