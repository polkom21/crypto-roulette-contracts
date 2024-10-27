import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const proxyModule = buildModule("ProxyModule", (m) => {
  const proxyAdminOwner = m.getAccount(0);

  const roulette = m.contract("Roulette");

  const encodedInitialize = m.encodeFunctionCall(roulette, "initialize", [
    m.getParameter("token"),
    m.getParameter("vrfV2PlusWrapper"),
  ]);

  const proxy = m.contract("TransparentUpgradeableProxy", [
    roulette,
    proxyAdminOwner,
    encodedInitialize,
  ]);

  const proxyAdminAddress = m.readEventArgument(
    proxy,
    "AdminChanged",
    "newAdmin"
  );

  const proxyAdmin = m.contractAt("ProxyAdmin", proxyAdminAddress);

  return { proxyAdmin, proxy };
});

export default proxyModule;
