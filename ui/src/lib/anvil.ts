"use client";

import {
  createPublicClient,
  createWalletClient,
  defineChain,
  formatEther,
  http,
  isAddress,
  parseEther,
  type Address,
  type Hash,
} from "viem";

export const anvilRpcUrl =
  process.env.NEXT_PUBLIC_ANVIL_RPC_URL ?? "http://127.0.0.1:8545";

export const anvilChain = defineChain({
  id: 31337,
  name: "Anvil",
  nativeCurrency: {
    decimals: 18,
    name: "Ether",
    symbol: "ETH",
  },
  rpcUrls: {
    default: {
      http: [anvilRpcUrl],
    },
  },
});

export const publicClient = createPublicClient({
  chain: anvilChain,
  transport: http(anvilRpcUrl),
});

export const walletClient = createWalletClient({
  chain: anvilChain,
  transport: http(anvilRpcUrl),
});

export type AnvilAccount = {
  address: Address;
  balance: bigint;
  balanceEth: string;
};

export async function getAnvilAccounts(): Promise<AnvilAccount[]> {
  const addresses = await walletClient.getAddresses();

  const accounts = await Promise.all(
    addresses.map(async (address) => {
      const balance = await publicClient.getBalance({ address });

      return {
        address,
        balance,
        balanceEth: formatEther(balance),
      };
    }),
  );

  return accounts;
}

export async function sendTestTransfer({
  from,
  to,
  amountEth,
}: {
  from: Address;
  to: Address;
  amountEth: string;
}): Promise<Hash> {
  if (!isAddress(from) || !isAddress(to)) {
    throw new Error("Sender and recipient must be valid addresses.");
  }

  return walletClient.sendTransaction({
    account: from,
    to,
    value: parseEther(amountEth),
  });
}

export function shortAddress(address: Address): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}
