import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import proxyModule from "./ProxyModule";

const upgradeModule = buildModule("UpgradeToV0_0_2", (m) => {
  const proxyAdminOwner = m.getAccount(0);

  const { proxyAdmin, proxy } = m.useModule(proxyModule);

  const RouletteV0_0_2 = m.contract("RouletteV0_0_2");

  m.call(proxyAdmin, "upgradeAndCall", [proxy, RouletteV0_0_2, "0x"], {
    from: proxyAdminOwner,
  });

  return { proxyAdmin, proxy };
});

export default upgradeModule;
