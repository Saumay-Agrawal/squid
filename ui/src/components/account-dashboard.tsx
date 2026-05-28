"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Database, RefreshCw, UserCircle2, Wallet } from "lucide-react";
import { type Address } from "viem";

import {
  anvilRpcUrl,
  getAnvilAccounts,
  shortAddress,
  type AnvilAccount,
} from "@/lib/anvil";
import {
  getSquidDeployment,
  getPoolCount,
  getPoolSummaries,
  type PoolSummary,
} from "@/lib/squid";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { ThemeToggle } from "@/components/theme-toggle";

type AppTab = "pools" | "profile";

const PAGE_SIZE = 20;

function formatBalance(balanceEth: string) {
  return `${Number(balanceEth).toFixed(4)} ETH`;
}

function formatCurrency(address: Address) {
  return address === "0x0000000000000000000000000000000000000000"
    ? "ETH"
    : shortAddress(address);
}

function formatPoolPair(pool: PoolSummary) {
  return `${formatCurrency(pool.currency0)} / ${formatCurrency(pool.currency1)}`;
}

function WalletSelector({
  accounts,
  isError,
  isLoading,
  selectedAddress,
  onSelect,
}: {
  accounts: AnvilAccount[];
  isError: boolean;
  isLoading: boolean;
  selectedAddress: Address | "";
  onSelect: (address: Address) => void;
}) {
  const placeholder = isLoading ? "Loading wallets..." : "Select wallet";

  return (
    <Select
      value={selectedAddress}
      onValueChange={(value) => onSelect(value as Address)}
      disabled={isError || isLoading || accounts.length === 0}
    >
      <SelectTrigger className="h-9 w-full min-w-0 max-w-full gap-2 md:w-[230px]">
        <Wallet className="size-4 text-muted-foreground" />
        <SelectValue placeholder={placeholder} />
      </SelectTrigger>
      <SelectContent align="end" className="w-[280px]">
        <SelectGroup>
          <SelectLabel>Wallets</SelectLabel>
          {accounts.map((account, index) => (
            <SelectItem key={account.address} value={account.address}>
              <span className="flex w-full min-w-0 items-center justify-between gap-3 font-mono">
                <span className="min-w-0 truncate font-mono">
                  #{index} {shortAddress(account.address)}
                </span>
                <span className="shrink-0 text-xs text-muted-foreground">
                  {formatBalance(account.balanceEth)}
                </span>
              </span>
            </SelectItem>
          ))}
        </SelectGroup>
      </SelectContent>
    </Select>
  );
}

function PoolsView({
  page,
  onPageChange,
}: {
  page: number;
  onPageChange: (page: number) => void;
}) {
  const deploymentQuery = useQuery({
    queryKey: ["squid-deployment"],
    queryFn: getSquidDeployment,
    retry: false,
  });

  const poolCountQuery = useQuery({
    queryKey: ["squid-pool-count"],
    queryFn: () => getPoolCount(deploymentQuery.data!.squidAddress),
    enabled: Boolean(deploymentQuery.data?.squidAddress),
    refetchInterval: 10_000,
  });

  const poolsQuery = useQuery({
    queryKey: ["squid-pool-summaries", page],
    queryFn: () =>
      getPoolSummaries(deploymentQuery.data!.squidAddress, page * PAGE_SIZE, PAGE_SIZE),
    enabled: Boolean(deploymentQuery.data?.squidAddress),
    refetchInterval: 10_000,
  });

  const totalPools = poolCountQuery.data ?? 0;
  const pageCount = totalPools === 0 ? 1 : Math.ceil(totalPools / PAGE_SIZE);
  const canGoBack = page > 0;
  const canGoForward = page + 1 < pageCount;

  if (deploymentQuery.isLoading) {
    return (
      <Card className="rounded-2xl">
        <CardContent className="p-6 text-sm text-muted-foreground">
          Resolving local Squid deployment.
        </CardContent>
      </Card>
    );
  }

  if (deploymentQuery.isError) {
    return (
      <Alert>
        <AlertTitle>Squid contract not configured</AlertTitle>
        <AlertDescription>
          {deploymentQuery.error.message}
        </AlertDescription>
      </Alert>
    );
  }

  if (poolCountQuery.isError || poolsQuery.isError) {
    return (
      <Alert variant="destructive">
        <AlertTitle>Unable to load pools</AlertTitle>
        <AlertDescription>
          {(poolCountQuery.error ?? poolsQuery.error)?.message}
        </AlertDescription>
      </Alert>
    );
  }

  return (
    <Card className="rounded-2xl">
      <CardHeader>
        <div className="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
          <div>
            <CardTitle>Pools</CardTitle>
            <CardDescription>
              Current pool registry from the Squid contract.
            </CardDescription>
          </div>
          <div className="flex items-center gap-2">
            <Badge variant="outline" className="rounded-md">
              {poolCountQuery.isLoading ? "Loading..." : `${totalPools} pools`}
            </Badge>
            <Badge variant="outline" className="rounded-md">
              {deploymentQuery.data?.source === "artifact"
                ? "Artifact config"
                : deploymentQuery.data?.source === "env+artifact"
                  ? "Env override"
                  : "Env config"}
            </Badge>
            <Button
              variant="outline"
              onClick={() => {
                void deploymentQuery.refetch();
                void poolCountQuery.refetch();
                void poolsQuery.refetch();
              }}
              disabled={
                deploymentQuery.isFetching ||
                poolCountQuery.isFetching ||
                poolsQuery.isFetching
              }
            >
              <RefreshCw
                className={`size-4 ${
                  deploymentQuery.isFetching ||
                  poolCountQuery.isFetching ||
                  poolsQuery.isFetching
                    ? "animate-spin"
                    : ""
                }`}
              />
              Refresh
            </Button>
          </div>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        {poolCountQuery.isLoading || poolsQuery.isLoading ? (
          <div className="rounded-xl border border-dashed p-8 text-sm text-muted-foreground">
            Loading current pools from Squid.
          </div>
        ) : null}

        {!poolCountQuery.isLoading &&
        !poolsQuery.isLoading &&
        (poolsQuery.data?.length ?? 0) === 0 ? (
          <div className="rounded-xl border border-dashed p-8 text-sm text-muted-foreground">
            No pools have been initialized yet.
          </div>
        ) : null}

        {(poolsQuery.data?.length ?? 0) > 0 ? (
          <>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Pair</TableHead>
                  <TableHead>Fee</TableHead>
                  <TableHead>Tick Spacing</TableHead>
                  <TableHead>Init Block</TableHead>
                  <TableHead>Active LPs</TableHead>
                  <TableHead>Active Positions</TableHead>
                  <TableHead>Tracked Liquidity</TableHead>
                  <TableHead>Swaps</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {poolsQuery.data?.map((pool) => (
                  <TableRow key={pool.poolId}>
                    <TableCell
                      className="font-mono text-xs sm:text-sm"
                      title={`${pool.currency0} / ${pool.currency1}`}
                    >
                      {formatPoolPair(pool)}
                    </TableCell>
                    <TableCell>{pool.fee}</TableCell>
                    <TableCell>{pool.tickSpacing}</TableCell>
                    <TableCell>{pool.initializedAtBlock.toString()}</TableCell>
                    <TableCell>{pool.activeLpCount.toString()}</TableCell>
                    <TableCell>{pool.activePositionCount.toString()}</TableCell>
                    <TableCell>{pool.trackedLiquidity.toString()}</TableCell>
                    <TableCell>{pool.swapCount.toString()}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>

            <div className="flex flex-col gap-3 border-t pt-4 text-sm sm:flex-row sm:items-center sm:justify-between">
              <p className="text-muted-foreground">
                Page {page + 1} of {pageCount}
              </p>
              <div className="flex items-center gap-2">
                <Button
                  variant="outline"
                  onClick={() => onPageChange(page - 1)}
                  disabled={!canGoBack}
                >
                  Previous
                </Button>
                <Button
                  variant="outline"
                  onClick={() => onPageChange(page + 1)}
                  disabled={!canGoForward}
                >
                  Next
                </Button>
              </div>
            </div>
          </>
        ) : null}
      </CardContent>
    </Card>
  );
}

function ProfileView({ selectedAccount }: { selectedAccount?: AnvilAccount }) {
  return (
    <Card className="rounded-2xl">
      <CardHeader>
        <CardTitle>Profile</CardTitle>
        <CardDescription>
          Wallet-scoped profile views can land here next.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {selectedAccount ? (
          <div className="rounded-xl border bg-muted/30 p-4">
            <p className="text-xs font-medium uppercase text-muted-foreground">
              Selected wallet
            </p>
            <p className="mt-2 font-mono text-sm break-all">
              {selectedAccount.address}
            </p>
            <p className="mt-2 text-sm text-muted-foreground">
              Balance: {formatBalance(selectedAccount.balanceEth)}
            </p>
          </div>
        ) : (
          <Alert>
            <AlertTitle>Select a wallet</AlertTitle>
            <AlertDescription>
              Choose an Anvil wallet from the header to anchor future profile
              views.
            </AlertDescription>
          </Alert>
        )}
      </CardContent>
    </Card>
  );
}

export function AccountDashboard() {
  const [selectedAddress, setSelectedAddress] = useState<Address | "">("");
  const [activeTab, setActiveTab] = useState<AppTab>("pools");
  const [page, setPage] = useState(0);

  const accountsQuery = useQuery({
    queryKey: ["anvil-accounts"],
    queryFn: getAnvilAccounts,
    refetchInterval: 4_000,
  });

  const accounts = accountsQuery.data ?? [];
  const selectedAccount = accounts.find(
    (account) => account.address === selectedAddress,
  );

  const tabs: Array<{
    id: AppTab;
    label: string;
    icon: typeof Database;
  }> = [
    { id: "pools", label: "Pools", icon: Database },
    { id: "profile", label: "Profile", icon: UserCircle2 },
  ];

  return (
    <main className="min-h-screen bg-background">
      <header className="border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/80">
        <nav className="mx-auto grid w-full max-w-7xl gap-3 px-4 py-4 sm:px-6 md:grid-cols-[1fr_auto_1fr] md:items-center lg:px-8">
          <div className="min-w-0">
            <h1 className="text-xl font-semibold tracking-normal">Squid</h1>
            <p className="text-sm text-muted-foreground">
              Onchain pool registry and operator workspace.
            </p>
          </div>

          <div className="flex min-w-0 items-center gap-2 md:justify-center">
            <Badge variant="outline" className="rounded-md">
              Local Anvil
            </Badge>
            <span className="min-w-0 truncate text-sm text-muted-foreground">
              {anvilRpcUrl}
            </span>
          </div>

          <div className="flex min-w-0 flex-col gap-2 sm:flex-row sm:items-center md:justify-end">
            <WalletSelector
              accounts={accounts}
              isError={accountsQuery.isError}
              isLoading={accountsQuery.isLoading}
              selectedAddress={selectedAddress}
              onSelect={setSelectedAddress}
            />
            <ThemeToggle />
          </div>
        </nav>
      </header>

      <div className="mx-auto grid w-full max-w-7xl gap-6 px-4 py-8 sm:px-6 lg:grid-cols-[240px_minmax(0,1fr)] lg:px-8">
        <aside className="rounded-2xl border bg-sidebar text-sidebar-foreground">
          <div className="border-b px-4 py-4">
            <p className="text-sm font-medium">Workspace</p>
            <p className="text-sm text-muted-foreground">
              Browse onchain views and account context.
            </p>
          </div>
          <div className="space-y-2 p-3">
            {tabs.map((tab) => {
              const Icon = tab.icon;

              return (
                <button
                  key={tab.id}
                  type="button"
                  onClick={() => {
                    setActiveTab(tab.id);
                    if (tab.id === "pools") {
                      setPage(0);
                    }
                  }}
                  className={`flex w-full items-center gap-3 rounded-xl px-3 py-3 text-left text-sm transition-colors ${
                    activeTab === tab.id
                      ? "bg-sidebar-primary text-sidebar-primary-foreground"
                      : "hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
                  }`}
                >
                  <Icon className="size-4" />
                  <span>{tab.label}</span>
                </button>
              );
            })}
          </div>
        </aside>

        <section className="space-y-6">
          {accountsQuery.isError ? (
            <Alert variant="destructive">
              <AlertTitle>Anvil RPC is unreachable</AlertTitle>
              <AlertDescription>
                Start Anvil on {anvilRpcUrl}, then refresh this page.
              </AlertDescription>
            </Alert>
          ) : null}

          {activeTab === "pools" ? (
            <PoolsView page={page} onPageChange={setPage} />
          ) : (
            <ProfileView selectedAccount={selectedAccount} />
          )}
        </section>
      </div>
    </main>
  );
}
