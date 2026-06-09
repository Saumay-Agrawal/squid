"use client";

import { ChartNoAxesColumn, Droplets, UserRound, Wallet } from "lucide-react";
import { useEffect, useState } from "react";

import { LpsView } from "@/components/lps-view";
import { PoolsView } from "@/components/pools-view";
import { ProfileView } from "@/components/profile-view";
import { ConnectWallet } from "@/components/wallet/connect-wallet";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { ThemeToggle } from "@/components/wallet/theme-toggle";
import type { SquidDashboardData } from "@/lib/dashboard";
import { cn, formatSignedAmount } from "@/lib/utils";

type Section = "pools" | "lps" | "profile";

const STORAGE_KEY = "squid-ui:selected-address";

export function DashboardShell({ data }: { data: SquidDashboardData }) {
  const [section, setSection] = useState<Section>("profile");
  const [selectedAddress, setSelectedAddress] = useState<string>(data.knownAddresses[0]?.address ?? "");

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
              <p className="truncate text-sm text-muted-foreground">Local simulation telemetry for pool health, LP concentration, and wallet exposure.</p>
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
          <Card className="h-full overflow-hidden border-sidebar-border/70 bg-sidebar/90">
            <CardHeader className="gap-4">
              <div>
                <CardTitle className="text-base">Workspace</CardTitle>
                <CardDescription>Navigate between market-wide pool views, the full LP roster, and the selected wallet.</CardDescription>
              </div>
            </CardHeader>
            <CardContent className="space-y-3">
              <SectionButton
                active={section === "pools"}
                icon={Droplets}
                label="Pools"
                meta={`${data.poolSummaries.length} pool snapshots`}
                onClick={() => setSection("pools")}
              />
              <SectionButton
                active={section === "lps"}
                icon={ChartNoAxesColumn}
                label="LPs"
                meta={`${data.lpSummaries.length} wallets tracked`}
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
                <SidebarContext section={section} profile={profile} />
              </div>
            </CardContent>
          </Card>
        </aside>

        <main className="min-w-0 space-y-4">
          {section === "pools" ? <PoolsView pools={data.poolSummaries} /> : null}
          {section === "lps" ? <LpsView lps={data.lpSummaries} selectedAddress={selectedAddress} /> : null}
          {section === "profile" ? (
            <ProfileView lps={data.lpSummaries} selectedAddress={selectedAddress} selectedLabel={activeAddress?.label ?? null} />
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
}: {
  section: Section;
  profile: SquidDashboardData["lpSummaries"][number] | null;
}) {
  const config =
    section === "pools"
      ? {
          title: "Pools view",
          note: "Compare fee tiers, active liquidity, and LP density across all simulated pools.",
          value: "Market-wide",
          positive: undefined,
        }
      : section === "lps"
        ? {
            title: "LP roster",
            note: "Browse every tracked wallet and inspect how capital is distributed across pools.",
            value: "Cross-wallet",
            positive: undefined,
          }
        : {
            title: "Selected wallet",
            note: profile ? `${profile.activePositionCount} active positions across ${profile.poolCount} pools.` : "Choose a wallet to load a profile summary.",
            value: profile ? formatSignedAmount(profile.totalPnl) : "No wallet",
            positive: profile ? profile.totalPnl >= 0n : undefined,
          };

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
      <div className="mt-2 text-sm text-muted-foreground">{config.note}</div>
    </div>
  );
}
