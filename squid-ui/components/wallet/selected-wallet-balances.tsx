"use client";

import { useReadContracts } from "wagmi";
import { erc20Abi, type Address } from "viem";

import { CardDescription } from "@/components/ui/card";
import { cn, formatTokenBalance } from "@/lib/utils";

type TokenConfig = {
  address: string;
  symbol: string;
};

export function SelectedWalletBalances({
  walletAddress,
  token0,
  token1,
}: {
  walletAddress: string;
  token0: TokenConfig;
  token1: TokenConfig;
}) {
  const { data, error, isLoading, isRefetching } = useReadContracts({
    allowFailure: false,
    contracts: [
      {
        address: token0.address as Address,
        abi: erc20Abi,
        functionName: "balanceOf",
        args: [walletAddress as Address],
      },
      {
        address: token0.address as Address,
        abi: erc20Abi,
        functionName: "decimals",
      },
      {
        address: token1.address as Address,
        abi: erc20Abi,
        functionName: "balanceOf",
        args: [walletAddress as Address],
      },
      {
        address: token1.address as Address,
        abi: erc20Abi,
        functionName: "decimals",
      },
    ],
    query: {
      enabled: Boolean(walletAddress),
      refetchInterval: 10_000,
    },
  });

  const [token0Balance, token0Decimals, token1Balance, token1Decimals] = data ?? [];

  return (
    <div className="mt-4 space-y-2 rounded-2xl border border-border/60 bg-card/60 p-3">
      <div className="flex items-center justify-between gap-3">
        <span className="text-xs uppercase tracking-[0.16em] text-muted-foreground">Live balances</span>
        {isRefetching ? <span className="text-[11px] text-muted-foreground">Refreshing</span> : null}
      </div>
      <BalanceRow
        label={token0.symbol}
        value={isLoading ? "Loading..." : token0Balance !== undefined && token0Decimals !== undefined ? formatTokenBalance(token0Balance, token0Decimals) : "N/A"}
      />
      <BalanceRow
        label={token1.symbol}
        value={isLoading ? "Loading..." : token1Balance !== undefined && token1Decimals !== undefined ? formatTokenBalance(token1Balance, token1Decimals) : "N/A"}
      />
      {error ? <CardDescription>Unable to read token balances from the local Anvil chain.</CardDescription> : null}
    </div>
  );
}

function BalanceRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-3 rounded-xl border border-border/50 bg-background/75 px-3 py-2.5">
      <span className="text-sm text-muted-foreground">{label}</span>
      <span className={cn("text-sm font-medium text-foreground", value === "Loading..." ? "text-muted-foreground" : "")}>{value}</span>
    </div>
  );
}
