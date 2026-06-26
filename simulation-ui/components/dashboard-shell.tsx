"use client";
import { Activity, BarChart3, Droplets, FlaskConical, LayoutDashboard, ListTree, Users } from "lucide-react";
import { useState } from "react";
import { ActionsView } from "@/components/actions-view";
import { ChartsView } from "@/components/charts-view";
import { OverviewView } from "@/components/overview-view";
import { ParticipantsView } from "@/components/participants-view";
import { PoolsView } from "@/components/pools-view";
import { PositionsView } from "@/components/positions-view";
import { ThemeToggle } from "@/components/wallet/theme-toggle";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import type { DashboardData } from "@/lib/simulation";
import { cn } from "@/lib/utils";

type Section = "overview" | "pools" | "positions" | "participants" | "actions" | "charts";
const navigation = [
  ["overview", "Overview", LayoutDashboard], ["pools", "Pools", Droplets], ["positions", "Positions", BarChart3],
  ["participants", "Participants", Users], ["actions", "Actions", ListTree], ["charts", "Historical charts", Activity],
] as const;

export function DashboardShell({ data }: { data: DashboardData }) {
  const [section, setSection] = useState<Section>("overview");
  return <div className="min-h-screen">
    <header className="sticky top-0 z-20 border-b border-border/70 bg-background/80 backdrop-blur"><div className="mx-auto flex max-w-[1600px] items-center justify-between gap-4 px-4 py-4 sm:px-6">
      <div className="flex items-center gap-3"><div className="rounded-2xl bg-primary/12 p-3 text-primary"><FlaskConical className="h-5 w-5" /></div>
        <div><p className="text-lg font-semibold">Squid Simulation</p><p className="text-sm text-muted-foreground">{data.actions.length} actions · {data.history.length} checkpoints</p></div></div>
      <div className="flex items-center gap-2"><Badge variant="secondary">Chain {data.chainId}</Badge><ThemeToggle /></div>
    </div></header>
    <div className="mx-auto grid max-w-[1600px] gap-4 px-4 py-4 sm:px-6 lg:grid-cols-[250px_minmax(0,1fr)]">
      <aside className="lg:sticky lg:top-24 lg:h-[calc(100vh-7rem)]"><Card className="h-full"><CardHeader><CardTitle className="text-base">Observer</CardTitle><CardDescription>Artifact-backed protocol state.</CardDescription></CardHeader>
        <CardContent className="space-y-2">{navigation.map(([value, label, Icon]) => <Button key={value} variant="ghost" onClick={() => setSection(value)} className={cn("w-full justify-start gap-3", section === value && "bg-primary/10 text-primary")}><Icon className="h-4 w-4" />{label}</Button>)}</CardContent>
      </Card></aside>
      <main className="min-w-0">{section === "overview" && <OverviewView data={data} />}{section === "pools" && <PoolsView data={data} />}
        {section === "positions" && <PositionsView data={data} />}{section === "participants" && <ParticipantsView data={data} />}
        {section === "actions" && <ActionsView data={data} />}{section === "charts" && <ChartsView data={data} />}</main>
    </div>
  </div>;
}
