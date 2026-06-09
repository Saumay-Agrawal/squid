"use client";

import { BarChart3, Droplets, FlaskConical, MoonStar, SunMedium, Wallet } from "lucide-react";
import { useMemo, useState } from "react";

import { PoolsView } from "@/components/pools-view";
import { PositionsView } from "@/components/positions-view";
import { ConnectWallet } from "@/components/wallet/connect-wallet";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { ThemeToggle } from "@/components/wallet/theme-toggle";
import type { DashboardData } from "@/lib/simulation";
import { cn } from "@/lib/utils";

type Section = "pools" | "positions";

export function DashboardShell({ data }: { data: DashboardData }) {
  const [section, setSection] = useState<Section>("pools");

  const activeScenarioLabel = useMemo(() => `${data.scenarios.length} scenarios loaded`, [data.scenarios.length]);

  return (
    <div className="min-h-screen">
      <header className="sticky top-0 z-20 border-b border-border/70 bg-background/80 backdrop-blur">
        <div className="mx-auto flex max-w-[1600px] items-center justify-between gap-4 px-4 py-4 sm:px-6">
          <div className="flex min-w-0 items-center gap-3">
            <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-primary/12 text-primary shadow-sm">
              <FlaskConical className="h-5 w-5" />
            </div>
            <div className="min-w-0">
              <p className="truncate text-lg font-semibold tracking-tight">Squid Simulation Dashboard</p>
              <p className="truncate text-sm text-muted-foreground">{activeScenarioLabel}</p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <Badge variant="secondary" className="hidden sm:inline-flex">
              Chain {data.chainId}
            </Badge>
            <ThemeToggle />
            <ConnectWallet />
          </div>
        </div>
      </header>

      <div className="mx-auto grid max-w-[1600px] gap-4 px-4 py-4 sm:px-6 lg:grid-cols-[280px_minmax(0,1fr)]">
        <aside className="lg:sticky lg:top-24 lg:h-[calc(100vh-7rem)]">
          <Card className="h-full overflow-hidden border-sidebar-border/70 bg-sidebar/85 backdrop-blur">
            <CardHeader className="pb-4">
              <CardTitle className="text-base">Views</CardTitle>
              <CardDescription>Switch between pool snapshots and LP outcomes.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              <SidebarButton
                active={section === "pools"}
                icon={Droplets}
                label="Existing Pools"
                meta={`${data.poolRows.length} pools`}
                onClick={() => setSection("pools")}
              />
              <SidebarButton
                active={section === "positions"}
                icon={BarChart3}
                label="Liquidity Positions"
                meta={`${data.positionRows.length} positions`}
                onClick={() => setSection("positions")}
              />

              <Separator className="my-4" />

              <div className="rounded-xl border border-border/70 bg-background/60 p-3">
                <div className="mb-2 flex items-center gap-2 text-sm font-medium">
                  <Wallet className="h-4 w-4 text-primary" />
                  Local chain context
                </div>
                <p className="text-sm text-muted-foreground">
                  Wallet connection is available for Anvil account selection and future live reads. The current dashboard
                  renders from the persisted simulation artifact.
                </p>
              </div>
            </CardContent>
          </Card>
        </aside>

        <main className="min-w-0 space-y-4">
          {section === "pools" ? <PoolsView data={data} /> : <PositionsView data={data} />}
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

