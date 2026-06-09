"use client";

import { useState } from "react";
import { ChevronDown } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { cn, formatAmount, formatAmountParts, formatFeeTier, formatSignedAmount, formatSignedAmountParts, shortenAddress, shortenHash, startCase } from "@/lib/utils";
import type { LpSummary } from "@/lib/dashboard";

export function ProfileView({
  lps,
  selectedAddress,
  selectedLabel,
}: {
  lps: LpSummary[];
  selectedAddress: string;
  selectedLabel: string | null;
}) {
  const profile = lps.find((entry) => entry.address === selectedAddress) ?? null;

  if (!profile) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Your Profile</CardTitle>
          <CardDescription>Select a local Anvil address to view its positions.</CardDescription>
        </CardHeader>
      </Card>
    );
  }

  const liquidityParts = formatAmountParts(profile.totalLiquidity);
  const pnlParts = formatSignedAmountParts(profile.totalPnl);
  const seededUsdParts = profile.seededUsdBalance === null ? null : formatAmountParts(profile.seededUsdBalance);
  const seededEthParts = profile.seededEthBalance === null ? null : formatAmountParts(profile.seededEthBalance);
  const feeCaptureParts = formatAmountParts(profile.totalFees);

  return (
    <div className="space-y-4">
      <Card className="overflow-hidden border-primary/10 bg-card/88 shadow-lg shadow-primary/5">
        <CardHeader className="gap-5">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
            <div className="space-y-1">
              <div className="flex flex-wrap items-center gap-2">
                <CardTitle className="text-xl">{selectedLabel ?? profile.label}</CardTitle>
                <Badge>You</Badge>
                {profile.tier ? <Badge variant="secondary">{startCase(profile.tier)}</Badge> : null}
                {profile.anchor ? <Badge variant="outline">Anchor</Badge> : null}
              </div>
              <CardDescription>{shortenAddress(profile.address)}</CardDescription>
            </div>
            <Badge variant="secondary">{profile.poolCount} pools</Badge>
          </div>
          <div className="grid gap-3 text-sm sm:grid-cols-2 xl:grid-cols-4">
            <StatLine label="Positions" value={String(profile.positionCount)} />
            <StatLine label="Active" value={String(profile.activePositionCount)} />
            <StatLine label="Liquidity" value={liquidityParts.primary} detail={liquidityParts.secondary} />
            <StatLine label="Net PnL" value={pnlParts.primary} detail={pnlParts.secondary} positive={profile.totalPnl >= 0n} />
          </div>
          <div className="grid gap-3 text-sm sm:grid-cols-2">
            <StatLine label="USD balance" value={seededUsdParts?.primary ?? "N/A"} detail={seededUsdParts?.secondary ?? null} />
            <StatLine label="ETH balance" value={seededEthParts?.primary ?? "N/A"} detail={seededEthParts?.secondary ?? null} />
          </div>
        </CardHeader>
        <CardContent className="grid gap-3 border-t border-border/70 bg-background/35 pt-5 sm:grid-cols-2 xl:grid-cols-4">
          <FocusBlock
            title="Exposure"
            value={`${profile.poolCount} pools`}
            note="Capital is spread across these markets in the final snapshot."
          />
          <FocusBlock
            title="Live positions"
            value={`${profile.activePositionCount}/${profile.positionCount}`}
            note="Positions currently in range at the simulated tick."
          />
          <FocusBlock
            title="Fee capture"
            value={feeCaptureParts.primary}
            detail={feeCaptureParts.secondary}
            note="Total accrued fees across all grouped positions."
          />
          <FocusBlock
            title="Planned positions"
            value={profile.plannedPositions === null ? "N/A" : String(profile.plannedPositions)}
            note="Original seeded target from the simulation manifest."
          />
        </CardContent>
      </Card>

      <ProfilePoolsBoard profile={profile} />
    </div>
  );
}

function ProfilePoolsBoard({ profile }: { profile: LpSummary }) {
  const [expandedPoolId, setExpandedPoolId] = useState<string | null>(profile.groups[0]?.poolId ?? null);

  return (
    <Card className="overflow-hidden">
      <CardHeader className="gap-2">
        <CardTitle className="text-xl">Your pools</CardTitle>
        <CardDescription>Expand a pool to inspect its positions inline instead of browsing separate cards.</CardDescription>
      </CardHeader>
      <CardContent className="px-0 pb-0">
        <div className="space-y-px">
          {profile.groups.map((group) => {
            const isExpanded = expandedPoolId === group.poolId;
            const detailId = `profile-pool-${group.poolId}`;
            const liquidityParts = formatAmountParts(group.totalLiquidity);
            const feeParts = formatAmountParts(group.totalFees);
            const pnlParts = formatSignedAmountParts(group.totalPnl);

            return (
              <div key={group.poolId} className="border-t border-border/60 first:border-t-0">
                <div className="grid items-center gap-3 px-6 py-4 text-sm lg:grid-cols-[minmax(0,1.6fr)_minmax(120px,0.7fr)_minmax(120px,0.7fr)_minmax(120px,0.7fr)_minmax(120px,0.7fr)_40px]">
                  <div>
                    <div className="font-semibold">{group.poolLabel}</div>
                    <div className="mt-1 text-xs text-muted-foreground">
                      Pool {group.poolIndex + 1} · {formatFeeTier(group.fee)} fee · spacing {group.tickSpacing}
                    </div>
                  </div>
                  <div>
                    <div className="text-xs uppercase tracking-[0.16em] text-muted-foreground">Liquidity</div>
                    <div className="mt-1 font-medium">{liquidityParts.primary}</div>
                  </div>
                  <div>
                    <div className="text-xs uppercase tracking-[0.16em] text-muted-foreground">Fees</div>
                    <div className="mt-1 font-medium">{feeParts.primary}</div>
                  </div>
                  <div>
                    <div className="text-xs uppercase tracking-[0.16em] text-muted-foreground">PnL</div>
                    <PnlValue value={pnlParts.primary} positive={group.totalPnl >= 0n} className="mt-1 font-medium" />
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
                  <div id={detailId} className="border-t border-border/60 bg-muted/20 px-6 py-5">
                    <div className="mx-auto max-w-5xl">
                      <div className="grid gap-3 text-sm sm:grid-cols-3">
                        <StatLine label="Liquidity" value={liquidityParts.primary} detail={liquidityParts.secondary} />
                        <StatLine label="Fees" value={feeParts.primary} detail={feeParts.secondary} />
                        <StatLine label="PnL" value={pnlParts.primary} detail={pnlParts.secondary} positive={group.totalPnl >= 0n} />
                      </div>
                      <div className="mt-4">
                        <ProfilePositionsBoard positions={group.positions} groupKey={`profile-${profile.address}-${group.poolId}`} />
                      </div>
                    </div>
                  </div>
                ) : null}
              </div>
            );
          })}
        </div>
      </CardContent>
    </Card>
  );
}

function ProfilePositionsBoard({
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
        const activeLiquidityParts = formatAmountParts(position.activeLiquidity);
        const totalLiquidityParts = formatAmountParts(position.liquidity);
        const feeParts = formatAmountParts(position.fees);

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
                  <StatLine label="Active liquidity" value={activeLiquidityParts.primary} detail={activeLiquidityParts.secondary} />
                </div>
                <div className="mt-3 grid gap-3 text-sm sm:grid-cols-2">
                  <StatLine label="Total liquidity" value={totalLiquidityParts.primary} detail={totalLiquidityParts.secondary} />
                  <StatLine label="Fees accrued" value={feeParts.primary} detail={feeParts.secondary} />
                </div>
              </div>
            ) : null}
          </div>
        );
      })}
    </div>
  );
}

function StatLine({
  label,
  value,
  detail,
  positive,
}: {
  label: string;
  value: string;
  detail?: string | null;
  positive?: boolean;
}) {
  return (
    <div className="flex items-center justify-between gap-4 rounded-2xl border border-border/60 bg-background/70 px-3 py-3">
      <span className="text-muted-foreground">{label}</span>
      <div className="text-right">
        <div className={positive === undefined ? "font-medium" : positive ? "font-medium text-emerald-600 dark:text-emerald-400" : "font-medium text-rose-600 dark:text-rose-400"}>
          {value}
        </div>
        {detail ? <div className="text-xs text-muted-foreground">{detail}</div> : null}
      </div>
    </div>
  );
}

function FocusBlock({ title, value, detail, note }: { title: string; value: string; detail?: string | null; note: string }) {
  return (
    <div className="rounded-3xl border border-border/70 bg-card/70 p-4">
      <div className="text-xs uppercase tracking-[0.16em] text-muted-foreground">{title}</div>
      <div className="mt-2 text-2xl font-semibold tracking-[-0.03em]">{value}</div>
      {detail ? <div className="mt-1 text-sm text-muted-foreground">{detail}</div> : null}
      <div className="mt-1 text-sm text-muted-foreground">{note}</div>
    </div>
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
