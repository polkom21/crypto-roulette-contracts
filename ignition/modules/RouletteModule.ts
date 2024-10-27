import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import proxyModule from "./ProxyModule";

const rouletteModule = buildModule("RouletteModule", (m) => {
  const { proxy, proxyAdmin } = m.useModule(proxyModule);

  const roulette = m.contractAt("Roulette", proxy);

  return { proxyAdmin, proxy, roulette };
});

export default rouletteModule;
