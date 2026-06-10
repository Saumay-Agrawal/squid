"use client";

import { ChartNoAxesColumn, Droplets, UserRound } from "lucide-react";
import { useEffect, useState } from "react";

import { LpsView } from "@/components/lps-view";
import { PoolsView } from "@/components/pools-view";
import { ProfileView } from "@/components/profile-view";
import { HexValue } from "@/components/ui/hex-value";
import { ConnectWallet } from "@/components/wallet/connect-wallet";
import { SelectedWalletBalances } from "@/components/wallet/selected-wallet-balances";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { ThemeToggle } from "@/components/wallet/theme-toggle";
import type { SquidDashboardData } from "@/lib/dashboard";
import { cn, formatSignedAmountParts } from "@/lib/utils";

type Section = "pools" | "lps" | "profile";

const STORAGE_KEY = "squid-ui:selected-address";

export function DashboardShell({ data }: { data: SquidDashboardData }) {
  const [section, setSection] = useState<Section>("profile");
  const [selectedAddress, setSelectedAddress] = useState<string>(data.knownAddresses[0]?.address ?? "");
  const [expandedPoolId, setExpandedPoolId] = useState<string | null>(data.poolSummaries[0]?.poolId ?? null);

  useEffect(() => {
    const saved = window.localStorage.getItem(STORAGE_KEY);

    if (saved && data.knownAddresses.some((entry) => entry.address === saved)) {
      setSelectedAddress(saved);
      return;
    }

    if (data.knownAddresses[0]?.address) {
      window.localStorage.setItem(STORAGE_KEY, data.knownAddresses[0].address);
    }
  }, [data.knownAddresses]);

  function handleAddressChange(address: string) {
    setSelectedAddress(address);
    window.localStorage.setItem(STORAGE_KEY, address);
  }

  const activeAddress = data.knownAddresses.find((entry) => entry.address === selectedAddress) ?? null;
  const profile = data.lpSummaries.find((entry) => entry.address === selectedAddress) ?? null;

  function handleOpenPoolDetails(poolId: string) {
    setExpandedPoolId(poolId);
    setSection("pools");
  }

  return (
    <div className="min-h-screen pb-10">
      <header className="sticky top-0 z-20 border-b border-border/70 bg-background/80 backdrop-blur-xl">
        <div className="mx-auto flex max-w-[1440px] items-center justify-between gap-4 px-4 py-4 sm:px-6">
          <div className="flex min-w-0 items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-primary text-primary-foreground shadow-lg shadow-primary/20">
              <Droplets className="h-5 w-5" />
            </div>
            <div className="min-w-0">
              <p className="truncate text-lg font-semibold tracking-tight">Squid LP Control Room</p>
              <p className="truncate text-sm text-muted-foreground">{data.seedManifest.description}</p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <Badge variant="secondary" className="hidden sm:inline-flex">
              Chain {data.chainId}
            </Badge>
            <ThemeToggle />
            <ConnectWallet
              addresses={data.knownAddresses}
              selectedAddress={selectedAddress}
              onSelectAddress={handleAddressChange}
            />
          </div>
        </div>
      </header>

      <div className="mx-auto grid max-w-[1440px] gap-4 px-4 py-6 sm:px-6 lg:grid-cols-[300px_minmax(0,1fr)]">
        <aside className="lg:sticky lg:top-24 lg:h-[calc(100vh-7rem)]">
          <Card className="flex h-full min-h-0 flex-col overflow-hidden border-sidebar-border/70 bg-sidebar/90">
            <CardHeader className="gap-4">
                <div>
                  <CardTitle className="text-base">Workspace</CardTitle>
                  <CardDescription>Navigate between market-wide pool health, the full LP roster, and the selected wallet.</CardDescription>
                </div>
            </CardHeader>
            <CardContent className="min-h-0 flex-1 space-y-3 overflow-y-auto">
              <SectionButton
                active={section === "pools"}
                icon={Droplets}
                label="Pools"
                meta={`${data.seedManifest.poolCount} seeded pools`}
                onClick={() => setSection("pools")}
              />
              <SectionButton
                active={section === "lps"}
                icon={ChartNoAxesColumn}
                label="LPs"
                meta={`${data.seedManifest.lpCount} seeded wallets`}
                onClick={() => setSection("lps")}
              />
              <SectionButton
                active={section === "profile"}
                icon={UserRound}
                label="Your Profile"
                meta={activeAddress ? activeAddress.label : "Choose a wallet"}
                onClick={() => setSection("profile")}
              />

              <div className="pt-3">
                <SidebarContext section={section} profile={profile} data={data} />
              </div>
            </CardContent>
          </Card>
        </aside>

        <main className="min-w-0 space-y-4">
          {section === "pools" ? <PoolsView pools={data.poolSummaries} expandedPoolId={expandedPoolId} onExpandedPoolChange={setExpandedPoolId} /> : null}
          {section === "lps" ? <LpsView lps={data.lpSummaries} selectedAddress={selectedAddress} /> : null}
          {section === "profile" ? (
            <ProfileView
              lps={data.lpSummaries}
              pools={data.poolSummaries}
              selectedAddress={selectedAddress}
              selectedLabel={activeAddress?.label ?? null}
              onOpenPoolDetails={handleOpenPoolDetails}
            />
          ) : null}
        </main>
      </div>
    </div>
  );
}

function SectionButton({
  active,
  icon: Icon,
  label,
  meta,
  onClick,
}: {
  active: boolean;
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  meta: string;
  onClick: () => void;
}) {
  return (
    <Button
      variant={active ? "secondary" : "ghost"}
      className={cn(
        "h-auto w-full justify-start rounded-3xl border px-4 py-4 text-left",
        active
          ? "border-primary/15 bg-primary/10 text-foreground shadow-sm shadow-primary/5"
          : "border-border/60 bg-background/55 text-muted-foreground hover:bg-background"
      )}
      onClick={onClick}
    >
      <div className="flex items-start gap-3">
        <div className={cn("rounded-2xl p-2.5", active ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground")}>
          <Icon className="h-4 w-4" />
        </div>
        <div>
          <div className="font-medium text-foreground">{label}</div>
          <div className="text-xs">{meta}</div>
        </div>
      </div>
    </Button>
  );
}

function SidebarContext({
  section,
  profile,
  data,
}: {
  section: Section;
  profile: SquidDashboardData["lpSummaries"][number] | null;
  data: SquidDashboardData;
}) {
  const profilePnlParts = profile ? formatSignedAmountParts(profile.totalPnl) : null;
  const config =
    section === "pools"
      ? {
          title: "Pools view",
          note: `${data.market.basePair} with utilization, retention, and trade-flow metrics across ${data.seedManifest.positionCount} seeded positions.`,
          value: `${data.seedManifest.poolCount} pools`,
          detail: null,
          positive: undefined,
        }
      : section === "lps"
        ? {
            title: "LP roster",
            note: `${data.seedManifest.swapCount} seeded swaps across ${data.seedManifest.lpCount} wallets, with token-level flow and PnL detail.`,
            value: `${data.seedManifest.lpCount} wallets`,
            detail: null,
            positive: undefined,
          }
        : null;

  if (section === "profile") {
    return (
      <div className="rounded-3xl border border-border/70 bg-background/65 p-4">
        <div className="text-xs uppercase tracking-[0.18em] text-muted-foreground">Selected wallet</div>
        <div className="mt-2 text-xl font-semibold tracking-[-0.03em] text-foreground">
          {profile?.label ?? "No wallet"}
        </div>
        <div className="mt-1 text-sm text-muted-foreground">
          {profile ? <HexValue value={profile.address} textClassName="text-sm text-muted-foreground" /> : "Choose a wallet to load token balances."}
        </div>
        <div className="mt-2 text-sm text-muted-foreground">
          {profile
            ? `${profile.activePositionCount} active positions across ${profile.poolCount} pools. Aggregate PnL ${profilePnlParts?.primary ?? "N/A"}.`
            : "Choose a wallet to load token balances."}
        </div>
        {profile ? (
          <SelectedWalletBalances
            walletAddress={profile.address}
            token0={{ address: data.market.token0, symbol: data.market.token0Symbol }}
            token1={{ address: data.market.token1, symbol: data.market.token1Symbol }}
          />
        ) : null}
        <div className="mt-4 space-y-2 rounded-2xl border border-border/60 bg-card/60 p-3 text-xs text-muted-foreground">
          <div className="flex items-center justify-between gap-3">
            <span>PoolManager</span>
            <HexValue value={data.contracts.poolManager} textClassName="text-[11px] text-foreground" />
          </div>
          <div className="flex items-center justify-between gap-3">
            <span>Squid hook</span>
            <HexValue value={data.contracts.squid} textClassName="text-[11px] text-foreground" />
          </div>
        </div>
      </div>
    );
  }

  if (!config) {
    return null;
  }

  return (
    <div className="rounded-3xl border border-border/70 bg-background/65 p-4">
      <div className="text-xs uppercase tracking-[0.18em] text-muted-foreground">{config.title}</div>
      <div
        className={cn(
          "mt-2 text-xl font-semibold tracking-[-0.03em]",
          config.positive === undefined ? "" : config.positive ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"
        )}
      >
        {config.value}
      </div>
      {config.detail ? <div className="mt-1 text-sm text-muted-foreground">{config.detail}</div> : null}
      <div className="mt-2 text-sm text-muted-foreground">{config.note}</div>
      <div className="mt-4 space-y-2 rounded-2xl border border-border/60 bg-card/60 p-3 text-xs text-muted-foreground">
        <div className="flex items-center justify-between gap-3">
          <span>PoolManager</span>
          <HexValue value={data.contracts.poolManager} textClassName="text-[11px] text-foreground" />
        </div>
        <div className="flex items-center justify-between gap-3">
          <span>Squid hook</span>
          <HexValue value={data.contracts.squid} textClassName="text-[11px] text-foreground" />
        </div>
      </div>
    </div>
  );
}
