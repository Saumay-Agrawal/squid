"use client";

import { useBalance, useReadContract } from "wagmi";
import { erc20Abi, type Address } from "viem";

import { CardDescription } from "@/components/ui/card";
import { cn, formatTokenBalance } from "@/lib/utils";
import { anvil } from "@/lib/wallet";

type TokenConfig = {
  address: string;
  symbol: string;
  decimals: number;
  native: boolean;
};

export function SelectedWalletBalances({
  walletAddress,
  token0,
  token1,
  seededToken0Balance,
  seededToken1Balance,
}: {
  walletAddress: string;
  token0: TokenConfig;
  token1: TokenConfig;
  seededToken0Balance?: bigint | null;
  seededToken1Balance?: bigint | null;
}) {
  const nativeToken = token0.native ? token0 : token1.native ? token1 : null;
  const erc20Token = token0.native ? token1 : token1.native ? token0 : null;

  const nativeBalanceQuery = useBalance({
    address: walletAddress as Address,
    chainId: anvil.id,
    query: {
      enabled: Boolean(walletAddress && nativeToken),
      refetchInterval: 10_000,
    },
  });

  const erc20BalanceQuery = useReadContract({
    address: erc20Token?.address as Address | undefined,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: walletAddress ? [walletAddress as Address] : undefined,
    chainId: anvil.id,
    query: {
      enabled: Boolean(walletAddress && erc20Token),
      refetchInterval: 10_000,
    },
  });

  const erc20DecimalsQuery = useReadContract({
    address: erc20Token?.address as Address | undefined,
    abi: erc20Abi,
    functionName: "decimals",
    chainId: anvil.id,
    query: {
      enabled: Boolean(erc20Token),
      refetchInterval: 10_000,
    },
  });

  const isLoading =
    nativeBalanceQuery.isLoading || erc20BalanceQuery.isLoading || erc20DecimalsQuery.isLoading;
  const isRefetching =
    nativeBalanceQuery.isRefetching || erc20BalanceQuery.isRefetching || erc20DecimalsQuery.isRefetching;
  const error =
    nativeBalanceQuery.error ?? erc20BalanceQuery.error ?? erc20DecimalsQuery.error;

  const balances = new Map<string, string>();

  if (nativeToken && nativeBalanceQuery.data) {
    balances.set(
      nativeToken.symbol,
      formatTokenBalance(nativeBalanceQuery.data.value, nativeToken.decimals),
    );
  }

  if (erc20Token && erc20BalanceQuery.data !== undefined) {
    balances.set(
      erc20Token.symbol,
      formatTokenBalance(
        erc20BalanceQuery.data,
        Number(erc20DecimalsQuery.data ?? erc20Token.decimals),
      ),
    );
  }

  if (!balances.has(token0.symbol) && seededToken0Balance !== null && seededToken0Balance !== undefined) {
    balances.set(token0.symbol, formatTokenBalance(seededToken0Balance, token0.decimals));
  }

  if (!balances.has(token1.symbol) && seededToken1Balance !== null && seededToken1Balance !== undefined) {
    balances.set(token1.symbol, formatTokenBalance(seededToken1Balance, token1.decimals));
  }

  return (
    <div className="mt-4 space-y-2 rounded-2xl border border-border/60 bg-card/60 p-3">
      <div className="flex items-center justify-between gap-3">
        <span className="text-xs uppercase tracking-[0.16em] text-muted-foreground">Live balances</span>
        {isRefetching ? <span className="text-[11px] text-muted-foreground">Refreshing</span> : null}
      </div>
      <BalanceRow
        label={token0.symbol}
        value={isLoading ? "Loading..." : balances.get(token0.symbol) ?? "N/A"}
      />
      <BalanceRow
        label={token1.symbol}
        value={isLoading ? "Loading..." : balances.get(token1.symbol) ?? "N/A"}
      />
      {error ? (
        <CardDescription>
          Unable to reach the local Anvil chain. Showing seeded balances from the simulation artifact.
        </CardDescription>
      ) : null}
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
