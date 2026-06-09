"use client";

import { ChartNoAxesColumn, Droplets, MoonStar, SunMedium, UserRound, Wallet } from "lucide-react";
import { useEffect, useState } from "react";

import { LpsView } from "@/components/lps-view";
import { PoolsView } from "@/components/pools-view";
import { ProfileView } from "@/components/profile-view";
import { ConnectWallet } from "@/components/wallet/connect-wallet";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { ThemeToggle } from "@/components/wallet/theme-toggle";
import type { SquidDashboardData } from "@/lib/dashboard";
import { cn } from "@/lib/utils";

type Section = "pools" | "lps" | "profile";

const STORAGE_KEY = "squid-ui:selected-address";

export function DashboardShell({ data }: { data: SquidDashboardData }) {
  const [section, setSection] = useState<Section>("pools");
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

  return (
    <div className="min-h-screen">
      <header className="sticky top-0 z-20 border-b border-border/70 bg-background/85 backdrop-blur">
        <div className="mx-auto flex max-w-[1440px] items-center justify-between gap-4 px-4 py-4 sm:px-6">
          <div className="flex min-w-0 items-center gap-3">
            <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-primary/12 text-primary shadow-sm">
              <Droplets className="h-5 w-5" />
            </div>
            <div className="min-w-0">
              <p className="truncate text-lg font-semibold tracking-tight">Squid UI</p>
              <p className="truncate text-sm text-muted-foreground">Passive LP dashboard for local Anvil simulations</p>
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

      <div className="mx-auto grid max-w-[1440px] gap-4 px-4 py-4 sm:px-6 lg:grid-cols-[280px_minmax(0,1fr)]">
        <aside className="lg:sticky lg:top-24 lg:h-[calc(100vh-7rem)]">
          <Card className="h-full overflow-hidden border-sidebar-border/70 bg-sidebar/85 backdrop-blur">
            <CardHeader className="pb-4">
              <CardTitle className="text-base">Explore</CardTitle>
              <CardDescription>Move between pool discovery, other LPs, and your profile.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              <SidebarButton
                active={section === "pools"}
                icon={Droplets}
                label="Pools"
                meta={`${data.poolSummaries.length} pool views`}
                onClick={() => setSection("pools")}
              />
              <SidebarButton
                active={section === "lps"}
                icon={ChartNoAxesColumn}
                label="LPs"
                meta={`${data.lpSummaries.length} LPs tracked`}
                onClick={() => setSection("lps")}
              />
              <SidebarButton
                active={section === "profile"}
                icon={UserRound}
                label="Your Profile"
                meta={activeAddress ? activeAddress.label : "Choose a wallet"}
                onClick={() => setSection("profile")}
              />

              <Separator className="my-4" />

              <div className="rounded-xl border border-border/70 bg-background/60 p-3 text-sm">
                <div className="mb-2 flex items-center gap-2 font-medium">
                  <Wallet className="h-4 w-4 text-primary" />
                  Passive LP focus
                </div>
                <p className="text-muted-foreground">
                  The default view prioritizes simple summaries first, then expandable detail when you want to dig deeper.
                </p>
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

function SidebarButton({
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
      variant="ghost"
      className={cn(
        "h-auto w-full justify-start rounded-2xl border border-transparent px-4 py-4 text-left",
        active
          ? "border-primary/25 bg-primary/10 text-foreground shadow-sm"
          : "bg-background/50 text-muted-foreground hover:bg-background"
      )}
      onClick={onClick}
    >
      <div className="flex items-start gap-3">
        <div className={cn("rounded-xl p-2", active ? "bg-primary/15 text-primary" : "bg-muted text-muted-foreground")}>
          <Icon className="h-4 w-4" />
        </div>
        <div>
          <div className="font-medium">{label}</div>
          <div className="text-xs">{meta}</div>
        </div>
      </div>
    </Button>
  );
}
