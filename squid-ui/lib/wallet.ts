import { createConfig, http } from "wagmi";
import { injected } from "wagmi/connectors";
import { createPublicClient, createWalletClient, defineChain, type Address } from "viem";
import { mnemonicToAccount } from "viem/accounts";

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

const ANVIL_MNEMONIC = "test test test test test test test test test test test junk";
const anvilAccounts = Array.from({ length: 20 }, (_, index) =>
  mnemonicToAccount(ANVIL_MNEMONIC, {
    accountIndex: index,
  }),
);
const anvilAccountByAddress = new Map(
  anvilAccounts.map((account) => [account.address.toLowerCase(), account] as const),
);

export const anvilPublicClient = createPublicClient({
  chain: anvil,
  transport: http(),
});

export function getAnvilAccount(address?: string | null) {
  if (!address) return null;
  return anvilAccountByAddress.get(address.toLowerCase()) ?? null;
}

export function hasLocalAnvilSigner(address?: string | null) {
  return getAnvilAccount(address) !== null;
}

export function createAnvilWalletClient(address: Address) {
  const account = getAnvilAccount(address);

  if (!account) {
    throw new Error(`No local Anvil signer is available for ${address}.`);
  }

  return createWalletClient({
    account,
    chain: anvil,
    transport: http(),
  });
}

export const wagmiConfig = createConfig({
  chains: [anvil],
  connectors: [injected()],
  transports: {
    [anvil.id]: http(),
  },
  ssr: true,
});
