import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import type { LpSummary } from "@/lib/dashboard";
import { cn, formatAmount, formatSignedAmount, shortenAddress, shortenHash } from "@/lib/utils";

export function LpsView({ lps, selectedAddress }: { lps: LpSummary[]; selectedAddress: string }) {
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

      {lps.map((lp) => {
        const isSelected = lp.address === selectedAddress;

        return (
          <Card key={lp.address} className={cn("overflow-hidden border-border/70", isSelected ? "ring-2 ring-primary/20" : "")}>
            <CardHeader className="gap-4">
              <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                <div className="space-y-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <CardTitle className="text-lg">{lp.label}</CardTitle>
                    {isSelected ? <Badge>You</Badge> : null}
                  </div>
                  <CardDescription>{shortenAddress(lp.address)}</CardDescription>
                </div>
                <div className="flex flex-wrap gap-2">
                  <Badge variant="secondary">{lp.poolCount} pools</Badge>
                  <Badge variant="outline">{lp.activePositionCount} active</Badge>
                </div>
              </div>
              <div className="grid gap-3 text-sm sm:grid-cols-2 xl:grid-cols-4">
                <StatLine label="Positions" value={String(lp.positionCount)} />
                <StatLine label="Liquidity" value={formatAmount(lp.totalLiquidity)} />
                <StatLine label="Fees" value={formatAmount(lp.totalFees)} />
                <StatLine label="Net PnL" value={formatSignedAmount(lp.totalPnl)} positive={lp.totalPnl >= 0n} />
              </div>
            </CardHeader>
            <CardContent className="space-y-3 border-t border-border/70 bg-background/35 pt-4">
              {lp.groups.map((group) => (
                <div key={`${lp.address}-${group.poolId}`} className="rounded-3xl border border-border/70 bg-background/80 p-4">
                  <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                    <div>
                      <div className="font-semibold">{group.poolLabel}</div>
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
                  <div className="mt-4 grid gap-2">
                    {group.positions.map((position) => (
                      <div
                        key={position.positionId}
                        className="grid gap-3 rounded-2xl border border-border/60 bg-card/75 px-4 py-4 text-sm lg:grid-cols-[minmax(0,1.3fr)_minmax(140px,0.7fr)_minmax(120px,0.5fr)_minmax(120px,0.5fr)]"
                      >
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
                          <div className={cn("mt-1 font-medium", position.netPnl >= 0n ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400")}>
                            {formatSignedAmount(position.netPnl)}
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </CardContent>
          </Card>
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
