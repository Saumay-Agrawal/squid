import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import type { LpSummary } from "@/lib/dashboard";
import { formatAmount, formatSignedAmount, shortenAddress, shortenHash } from "@/lib/utils";

export function LpsView({ lps, selectedAddress }: { lps: LpSummary[]; selectedAddress: string }) {
  return (
    <div className="space-y-4">
      {lps.map((lp) => {
        const isSelected = lp.address === selectedAddress;

        return (
          <details key={lp.address} className="group">
            <Card className="overflow-hidden">
              <summary className="cursor-pointer list-none">
                <CardHeader className="gap-3">
                  <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                    <div className="space-y-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <CardTitle className="text-base">{lp.label}</CardTitle>
                        {isSelected ? <Badge>You</Badge> : null}
                      </div>
                      <CardDescription>{shortenAddress(lp.address)}</CardDescription>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      <Badge variant="secondary">{lp.poolCount} pools</Badge>
                      <Badge variant="outline">{lp.activePositionCount} active</Badge>
                    </div>
                  </div>
                  <div className="grid gap-3 text-sm text-muted-foreground sm:grid-cols-2 xl:grid-cols-4">
                    <StatLine label="Positions" value={String(lp.positionCount)} />
                    <StatLine label="Liquidity" value={formatAmount(lp.totalLiquidity)} />
                    <StatLine label="Fees" value={formatAmount(lp.totalFees)} />
                    <StatLine label="Net PnL" value={formatSignedAmount(lp.totalPnl)} positive={lp.totalPnl >= 0n} />
                  </div>
                </CardHeader>
              </summary>
              <CardContent className="space-y-3 border-t border-border/70 bg-background/40 pt-4">
                {lp.groups.map((group) => (
                  <div key={`${lp.address}-${group.poolId}`} className="rounded-2xl border border-border/70 bg-background/80 p-4">
                    <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
                      <div>
                        <div className="font-medium">{group.poolLabel}</div>
                        <div className="text-sm text-muted-foreground">{group.scenarioName}</div>
                      </div>
                      <div className="flex flex-wrap gap-2">
                        <Badge variant="secondary">{group.positionCount} positions</Badge>
                        <Badge variant="outline">{group.activePositionCount} active</Badge>
                      </div>
                    </div>
                    <div className="mt-3 grid gap-3 text-sm sm:grid-cols-3">
                      <StatLine label="Liquidity" value={formatAmount(group.totalLiquidity)} />
                      <StatLine label="Fees" value={formatAmount(group.totalFees)} />
                      <StatLine label="PnL" value={formatSignedAmount(group.totalPnl)} positive={group.totalPnl >= 0n} />
                    </div>
                    <div className="mt-3 space-y-2">
                      {group.positions.map((position) => (
                        <div
                          key={position.positionId}
                          className="grid gap-2 rounded-xl border border-border/60 bg-background/70 px-3 py-3 text-sm sm:grid-cols-[minmax(0,1fr)_auto_auto]"
                        >
                          <div>
                            <div className="font-medium">
                              Range [{position.tickLower}, {position.tickUpper}]
                            </div>
                            <div className="font-mono text-xs text-muted-foreground">{shortenHash(position.positionId)}</div>
                          </div>
                          <div className="flex items-center gap-2">
                            <Badge variant={position.active ? "default" : "outline"}>
                              {position.active ? "Active" : "Inactive"}
                            </Badge>
                            <span className="font-medium">{formatAmount(position.liquidity)}</span>
                          </div>
                          <div className={position.netPnl >= 0n ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"}>
                            {formatSignedAmount(position.netPnl)}
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </CardContent>
            </Card>
          </details>
        );
      })}
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
    <div className="flex items-center justify-between gap-4 rounded-xl border border-border/60 bg-background/70 px-3 py-2">
      <span className="text-muted-foreground">{label}</span>
      <span className={positive === undefined ? "font-medium" : positive ? "font-medium text-emerald-600 dark:text-emerald-400" : "font-medium text-rose-600 dark:text-rose-400"}>
        {value}
      </span>
    </div>
  );
}
