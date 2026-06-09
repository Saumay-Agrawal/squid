"use client";

import { Fragment, useState } from "react";
import { ChevronDown } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { LpSummary } from "@/lib/dashboard";
import { cn, formatAmount, formatFeeTier, formatSignedAmount, shortenAddress, shortenHash, startCase } from "@/lib/utils";

export function LpsView({ lps, selectedAddress }: { lps: LpSummary[]; selectedAddress: string }) {
  const [expandedAddress, setExpandedAddress] = useState<string | null>(selectedAddress || (lps[0]?.address ?? null));
  const activeWallets = lps.filter((lp) => lp.activePositionCount > 0).length;
  const totalLiquidity = lps.reduce((sum, lp) => sum + lp.totalLiquidity, 0n);
  const totalPnl = lps.reduce((sum, lp) => sum + lp.totalPnl, 0n);

  return (
    <div className="space-y-4">
      <section className="grid gap-4 md:grid-cols-3">
        <MetricCard title="Tracked wallets" value={String(lps.length)} note={`${activeWallets} wallets currently have active positions`} />
        <MetricCard title="Aggregate liquidity" value={formatAmount(totalLiquidity)} note="Combined liquidity across every tracked LP snapshot" />
        <MetricCard title="Aggregate PnL" value={formatSignedAmount(totalPnl)} note="Net outcome across all tracked LPs" positive={totalPnl >= 0n} />
      </section>

      <Card className="overflow-hidden">
        <CardHeader className="gap-2">
          <CardTitle className="text-xl">LP board</CardTitle>
          <CardDescription>Compare wallets by exposure, activity, and outcome, then expand one wallet for grouped pool and position details.</CardDescription>
        </CardHeader>
        <CardContent className="px-0 pb-0">
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="pl-6">Wallet</TableHead>
                  <TableHead>Liquidity</TableHead>
                  <TableHead>Fees</TableHead>
                  <TableHead>PnL</TableHead>
                  <TableHead>Pools</TableHead>
                  <TableHead>Positions</TableHead>
                  <TableHead>Planned</TableHead>
                  <TableHead className="w-12 pr-6"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {lps.map((lp) => {
                  const isExpanded = expandedAddress === lp.address;
                  const isSelected = lp.address === selectedAddress;
                  const detailId = `lp-detail-${lp.address}`;

                  return (
                    <Fragment key={lp.address}>
                      <TableRow className={cn("bg-transparent", isSelected ? "bg-primary/5" : "")}>
                        <TableCell className="pl-6">
                          <div className="min-w-52">
                            <div className="flex flex-wrap items-center gap-2">
                              <span className="font-semibold">{lp.label}</span>
                              {isSelected ? <Badge>You</Badge> : null}
                              {lp.tier ? <Badge variant="secondary">{startCase(lp.tier)}</Badge> : null}
                              {lp.anchor ? <Badge variant="outline">Anchor</Badge> : null}
                            </div>
                            <div className="mt-1 text-xs text-muted-foreground">{shortenAddress(lp.address)}</div>
                          </div>
                        </TableCell>
                        <TableCell>{formatAmount(lp.totalLiquidity)}</TableCell>
                        <TableCell>{formatAmount(lp.totalFees)}</TableCell>
                        <TableCell>
                          <PnlValue value={formatSignedAmount(lp.totalPnl)} positive={lp.totalPnl >= 0n} />
                        </TableCell>
                        <TableCell>{lp.poolCount}</TableCell>
                        <TableCell>
                          <MetricStack primary={String(lp.positionCount)} secondary={`${lp.activePositionCount} active`} />
                        </TableCell>
                        <TableCell>{lp.plannedPositions === null ? "N/A" : String(lp.plannedPositions)}</TableCell>
                        <TableCell className="pr-6 text-right">
                          <button
                            type="button"
                            aria-expanded={isExpanded}
                            aria-controls={detailId}
                            aria-label={`${isExpanded ? "Collapse" : "Expand"} ${lp.label}`}
                            className="inline-flex h-8 w-8 items-center justify-center rounded-full border border-border/70 bg-background/70 text-muted-foreground transition hover:bg-accent hover:text-foreground"
                            onClick={() => setExpandedAddress(isExpanded ? null : lp.address)}
                          >
                            <ChevronDown className={cn("h-4 w-4 transition-transform", isExpanded ? "rotate-180" : "")} />
                          </button>
                        </TableCell>
                      </TableRow>
                      {isExpanded ? (
                        <TableRow className="bg-transparent hover:bg-transparent">
                          <TableCell className="border-0 bg-muted/20 p-0" colSpan={8} id={detailId}>
                            <div className="px-6 py-5">
                              <div className="mx-auto max-w-5xl">
                                <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                                  <div className="space-y-1">
                                    <div className="flex flex-wrap items-center gap-2">
                                      <div className="text-base font-semibold">{lp.label}</div>
                                      {isSelected ? <Badge>You</Badge> : null}
                                      {lp.tier ? <Badge variant="secondary">{startCase(lp.tier)}</Badge> : null}
                                      {lp.anchor ? <Badge variant="outline">Anchor</Badge> : null}
                                    </div>
                                    <div className="text-sm text-muted-foreground">{shortenAddress(lp.address)}</div>
                                  </div>
                                  <div className="flex flex-wrap gap-2">
                                    <Badge variant="secondary">{lp.poolCount} pools</Badge>
                                    <Badge variant="outline">{lp.activePositionCount} active</Badge>
                                  </div>
                                </div>

                                <div className="mt-4 grid gap-3 text-sm sm:grid-cols-2 xl:grid-cols-5">
                                  <StatLine label="Positions" value={String(lp.positionCount)} />
                                  <StatLine label="Planned" value={lp.plannedPositions === null ? "N/A" : String(lp.plannedPositions)} />
                                  <StatLine label="Liquidity" value={formatAmount(lp.totalLiquidity)} />
                                  <StatLine label="Fees" value={formatAmount(lp.totalFees)} />
                                  <StatLine label="Net PnL" value={formatSignedAmount(lp.totalPnl)} positive={lp.totalPnl >= 0n} />
                                </div>

                                <div className="mt-3 grid gap-3 text-sm sm:grid-cols-2">
                                  <StatLine label="Seeded USD" value={lp.seededUsdBalance === null ? "N/A" : formatAmount(lp.seededUsdBalance)} />
                                  <StatLine label="Seeded ETH" value={lp.seededEthBalance === null ? "N/A" : formatAmount(lp.seededEthBalance)} />
                                </div>

                                <div className="mt-5">
                                  <LpGroupsView groups={lp.groups} lpAddress={lp.address} />
                                </div>
                              </div>
                            </div>
                          </TableCell>
                        </TableRow>
                      ) : null}
                    </Fragment>
                  );
                })}
              </TableBody>
            </Table>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

function StatLine({
  label,
  value,
  positive,
}: {
  label: string;
  value: string;
  positive?: boolean;
}) {
  return (
    <div className="flex items-center justify-between gap-4 rounded-2xl border border-border/60 bg-background/70 px-3 py-3">
      <span className="text-muted-foreground">{label}</span>
      <span className={positive === undefined ? "font-medium" : positive ? "font-medium text-emerald-600 dark:text-emerald-400" : "font-medium text-rose-600 dark:text-rose-400"}>
        {value}
      </span>
    </div>
  );
}

function MetricCard({
  title,
  value,
  note,
  positive,
}: {
  title: string;
  value: string;
  note: string;
  positive?: boolean;
}) {
  return (
    <Card>
      <CardHeader className="space-y-2">
        <CardDescription className="uppercase tracking-[0.14em]">{title}</CardDescription>
        <CardTitle
          className={cn(
            "text-2xl tracking-[-0.03em]",
            positive === undefined ? "" : positive ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"
          )}
        >
          {value}
        </CardTitle>
      </CardHeader>
      <CardContent className="text-sm text-muted-foreground">{note}</CardContent>
    </Card>
  );
}

function MetricStack({ primary, secondary }: { primary: string; secondary: string }) {
  return (
    <div>
      <div className="font-medium">{primary}</div>
      <div className="text-xs text-muted-foreground">{secondary}</div>
    </div>
  );
}

function PnlValue({
  value,
  positive,
  className,
}: {
  value: string;
  positive: boolean;
  className?: string;
}) {
  return <div className={cn(positive ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400", className)}>{value}</div>;
}

function GroupPositionsView({
  positions,
  groupKey,
}: {
  positions: LpSummary["groups"][number]["positions"];
  groupKey: string;
}) {
  const [expandedPositionId, setExpandedPositionId] = useState<string | null>(positions[0]?.positionId ?? null);

  return (
    <div className="space-y-2">
      {positions.map((position) => {
        const isExpanded = expandedPositionId === position.positionId;
        const detailId = `${groupKey}-${position.positionId}`;

        return (
          <div key={position.positionId} className="overflow-hidden rounded-2xl border border-border/60 bg-card/75">
            <div className="grid items-center gap-3 px-4 py-4 text-sm lg:grid-cols-[minmax(0,1.4fr)_minmax(140px,0.7fr)_minmax(120px,0.5fr)_minmax(120px,0.5fr)_40px]">
              <div>
                <div className="font-medium">
                  Range [{position.tickLower}, {position.tickUpper}]
                </div>
                <div className="mt-1 font-mono text-xs text-muted-foreground">{shortenHash(position.positionId)}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-[0.16em] text-muted-foreground">Status</div>
                <div className="mt-1">
                  <Badge variant={position.active ? "default" : "outline"} className={position.active ? "bg-emerald-600 text-white" : ""}>
                    {position.active ? "Active" : "Inactive"}
                  </Badge>
                </div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-[0.16em] text-muted-foreground">Liquidity</div>
                <div className="mt-1 font-medium">{formatAmount(position.liquidity)}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-[0.16em] text-muted-foreground">PnL</div>
                <PnlValue value={formatSignedAmount(position.netPnl)} positive={position.netPnl >= 0n} className="mt-1 font-medium" />
              </div>
              <div className="text-right">
                <button
                  type="button"
                  aria-expanded={isExpanded}
                  aria-controls={detailId}
                  aria-label={`${isExpanded ? "Collapse" : "Expand"} position ${shortenHash(position.positionId)}`}
                  className="inline-flex h-8 w-8 items-center justify-center rounded-full border border-border/70 bg-background/70 text-muted-foreground transition hover:bg-accent hover:text-foreground"
                  onClick={() => setExpandedPositionId(isExpanded ? null : position.positionId)}
                >
                  <ChevronDown className={cn("h-4 w-4 transition-transform", isExpanded ? "rotate-180" : "")} />
                </button>
              </div>
            </div>
            {isExpanded ? (
              <div id={detailId} className="border-t border-border/60 bg-background/55 px-4 py-4">
                <div className="grid gap-3 text-sm sm:grid-cols-3">
                  <StatLine label="Position ID" value={shortenHash(position.positionId)} />
                  <StatLine label="Range width" value={String(position.tickUpper - position.tickLower)} />
                  <StatLine label="Active liquidity" value={formatAmount(position.activeLiquidity)} />
                </div>
                <div className="mt-3 grid gap-3 text-sm sm:grid-cols-2">
                  <StatLine label="Total liquidity" value={formatAmount(position.liquidity)} />
                  <StatLine label="Fees accrued" value={formatAmount(position.fees)} />
                </div>
              </div>
            ) : null}
          </div>
        );
      })}
    </div>
  );
}

function LpGroupsView({
  groups,
  lpAddress,
}: {
  groups: LpSummary["groups"];
  lpAddress: string;
}) {
  const [expandedPoolId, setExpandedPoolId] = useState<string | null>(groups[0]?.poolId ?? null);

  return (
    <div className="space-y-3">
      {groups.map((group) => {
        const isExpanded = expandedPoolId === group.poolId;
        const detailId = `${lpAddress}-${group.poolId}`;

        return (
          <div key={group.poolId} className="overflow-hidden rounded-3xl border border-border/70 bg-background/65">
            <div className="grid items-center gap-3 px-4 py-4 text-sm lg:grid-cols-[minmax(0,1.5fr)_minmax(120px,0.7fr)_minmax(120px,0.7fr)_minmax(120px,0.7fr)_minmax(120px,0.7fr)_40px]">
              <div>
                <div className="font-semibold">{group.poolLabel}</div>
                <div className="text-sm text-muted-foreground">Pool {group.poolIndex + 1} · {formatFeeTier(group.fee)} fee · spacing {group.tickSpacing}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-[0.16em] text-muted-foreground">Liquidity</div>
                <div className="mt-1 font-medium">{formatAmount(group.totalLiquidity)}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-[0.16em] text-muted-foreground">Fees</div>
                <div className="mt-1 font-medium">{formatAmount(group.totalFees)}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-[0.16em] text-muted-foreground">PnL</div>
                <PnlValue value={formatSignedAmount(group.totalPnl)} positive={group.totalPnl >= 0n} className="mt-1 font-medium" />
              </div>
              <div>
                <div className="text-xs uppercase tracking-[0.16em] text-muted-foreground">Positions</div>
                <div className="mt-1">
                  <MetricStack primary={String(group.positionCount)} secondary={`${group.activePositionCount} active`} />
                </div>
              </div>
              <div className="text-right">
                <button
                  type="button"
                  aria-expanded={isExpanded}
                  aria-controls={detailId}
                  aria-label={`${isExpanded ? "Collapse" : "Expand"} ${group.poolLabel}`}
                  className="inline-flex h-8 w-8 items-center justify-center rounded-full border border-border/70 bg-background/70 text-muted-foreground transition hover:bg-accent hover:text-foreground"
                  onClick={() => setExpandedPoolId(isExpanded ? null : group.poolId)}
                >
                  <ChevronDown className={cn("h-4 w-4 transition-transform", isExpanded ? "rotate-180" : "")} />
                </button>
              </div>
            </div>
            {isExpanded ? (
              <div id={detailId} className="border-t border-border/60 bg-background/55 px-4 py-4">
                <div className="grid gap-3 text-sm sm:grid-cols-3">
                  <StatLine label="Liquidity" value={formatAmount(group.totalLiquidity)} />
                  <StatLine label="Fees" value={formatAmount(group.totalFees)} />
                  <StatLine label="PnL" value={formatSignedAmount(group.totalPnl)} positive={group.totalPnl >= 0n} />
                </div>
                <div className="mt-4">
                  <GroupPositionsView positions={group.positions} groupKey={`${lpAddress}-${group.poolId}`} />
                </div>
              </div>
            ) : null}
          </div>
        );
      })}
    </div>
  );
}
