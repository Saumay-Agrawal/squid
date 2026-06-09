"use client";

import { useMemo, useState } from "react";
import { Coins, Filter, Percent, Radar } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { DashboardData } from "@/lib/simulation";
import { formatAmount, formatSignedAmount, shortenAddress, shortenHash } from "@/lib/utils";

export function PositionsView({ data }: { data: DashboardData }) {
  const [selectedScenario, setSelectedScenario] = useState<string>("all");
  const [status, setStatus] = useState<"all" | "active" | "inactive">("all");

  const filtered = useMemo(() => {
    return data.positionRows.filter((row) => {
      if (selectedScenario !== "all" && row.scenarioName !== selectedScenario) return false;
      if (status === "active" && !row.active) return false;
      if (status === "inactive" && row.active) return false;
      return true;
    });
  }, [data.positionRows, selectedScenario, status]);

  const activeCount = filtered.filter((row) => row.active).length;
  const totalFees = filtered.reduce((sum, row) => sum + row.feeAccumulated0 + row.feeAccumulated1, 0n);
  const totalPnl = filtered.reduce((sum, row) => sum + row.netPnl0 + row.netPnl1, 0n);

  return (
    <div className="space-y-4">
      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <MetricCard title="Visible Positions" value={String(filtered.length)} note="Rows after filters" icon={Coins} />
        <MetricCard title="Active" value={String(activeCount)} note="Still in range or funded" icon={Radar} />
        <MetricCard title="Fees Accrued" value={formatAmount(totalFees)} note="fee0 + fee1, summed raw units" icon={Percent} />
        <MetricCard title="Net PnL" value={formatSignedAmount(totalPnl)} note="netPnl0 + netPnl1, summed raw units" icon={Filter} />
      </section>

      <Card>
        <CardHeader className="gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <CardTitle>Liquidity Positions</CardTitle>
            <CardDescription>Filter LP outcomes by scenario and active status.</CardDescription>
          </div>
          <div className="flex flex-wrap gap-2">
            <FilterGroup
              values={["all", ...data.scenarios.map((scenario) => scenario.name)]}
              active={selectedScenario}
              onChange={setSelectedScenario}
            />
            <FilterGroup values={["all", "active", "inactive"]} active={status} onChange={(value) => setStatus(value as typeof status)} />
          </div>
        </CardHeader>
        <CardContent className="overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>LP</TableHead>
                <TableHead>Scenario</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Range</TableHead>
                <TableHead>Liquidity</TableHead>
                <TableHead>Fees</TableHead>
                <TableHead>Net PnL</TableHead>
                <TableHead>Position Id</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filtered.map((row) => (
                <TableRow key={row.positionId}>
                  <TableCell className="font-mono text-xs">{shortenAddress(row.lp)}</TableCell>
                  <TableCell>{row.scenarioName}</TableCell>
                  <TableCell>
                    <Badge variant={row.active ? "default" : "secondary"}>{row.active ? "Active" : "Inactive"}</Badge>
                  </TableCell>
                  <TableCell className="font-mono text-xs">
                    [{row.tickLower}, {row.tickUpper}]
                  </TableCell>
                  <TableCell>{formatAmount(row.totalLiquidity)}</TableCell>
                  <TableCell>{formatAmount(row.feeAccumulated0 + row.feeAccumulated1)}</TableCell>
                  <TableCell className={row.netPnl0 + row.netPnl1 >= 0n ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"}>
                    {formatSignedAmount(row.netPnl0 + row.netPnl1)}
                  </TableCell>
                  <TableCell className="font-mono text-xs">{shortenHash(row.positionId)}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}

function MetricCard({
  title,
  value,
  note,
  icon: Icon,
}: {
  title: string;
  value: string;
  note: string;
  icon: React.ComponentType<{ className?: string }>;
}) {
  return (
    <Card>
      <CardHeader className="flex flex-row items-start justify-between space-y-0">
        <div>
          <CardDescription>{title}</CardDescription>
          <CardTitle className="mt-2 text-2xl">{value}</CardTitle>
        </div>
        <div className="rounded-2xl bg-primary/10 p-3 text-primary">
          <Icon className="h-4 w-4" />
        </div>
      </CardHeader>
      <CardContent className="text-sm text-muted-foreground">{note}</CardContent>
    </Card>
  );
}

function FilterGroup({
  values,
  active,
  onChange,
}: {
  values: string[];
  active: string;
  onChange: (value: string) => void;
}) {
  return (
    <div className="flex flex-wrap gap-2">
      {values.map((value) => (
        <Button
          key={value}
          variant={active === value ? "default" : "outline"}
          size="sm"
          onClick={() => onChange(value)}
          className="capitalize"
        >
          {value.replaceAll("-", " ")}
        </Button>
      ))}
    </div>
  );
}
