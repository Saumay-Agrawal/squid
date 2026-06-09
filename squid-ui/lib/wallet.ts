import { createConfig, http } from "wagmi";
import { injected } from "wagmi/connectors";
import { defineChain } from "viem";

export const anvil = defineChain({
  id: 31337,
  name: "Anvil Local",
  nativeCurrency: {
    decimals: 18,
    name: "Ether",
    symbol: "ETH",
  },
  rpcUrls: {
    default: {
      http: ["http://127.0.0.1:8545"],
    },
  },
  blockExplorers: {
    default: {
      name: "Localhost",
      url: "http://127.0.0.1:8545",
    },
  },
  testnet: true,
});

export const wagmiConfig = createConfig({
  chains: [anvil],
  connectors: [injected()],
  transports: {
    [anvil.id]: http(),
  },
  ssr: true,
});

