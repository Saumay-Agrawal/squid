import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import type { LpSummary } from "@/lib/dashboard";
import { formatAmount, formatSignedAmount, shortenAddress, shortenHash } from "@/lib/utils";

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

  return (
    <div className="space-y-4">
      <Card>
        <CardHeader className="gap-3">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <CardTitle className="text-base">{selectedLabel ?? profile.label}</CardTitle>
                <Badge>You</Badge>
              </div>
              <CardDescription>{shortenAddress(profile.address)}</CardDescription>
            </div>
            <Badge variant="secondary">{profile.poolCount} pools</Badge>
          </div>
          <div className="grid gap-3 text-sm text-muted-foreground sm:grid-cols-2 xl:grid-cols-4">
            <StatLine label="Positions" value={String(profile.positionCount)} />
            <StatLine label="Active" value={String(profile.activePositionCount)} />
            <StatLine label="Liquidity" value={formatAmount(profile.totalLiquidity)} />
            <StatLine label="Net PnL" value={formatSignedAmount(profile.totalPnl)} positive={profile.totalPnl >= 0n} />
          </div>
        </CardHeader>
      </Card>

      <div className="space-y-4">
        {profile.groups.map((group) => (
          <details key={`${profile.address}-${group.poolId}`} className="group">
            <Card className="overflow-hidden">
              <summary className="cursor-pointer list-none">
                <CardHeader className="gap-3">
                  <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                    <div>
                      <CardTitle className="text-base">{group.poolLabel}</CardTitle>
                      <CardDescription>{group.scenarioName}</CardDescription>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      <Badge variant="secondary">{group.positionCount} positions</Badge>
                      <Badge variant="outline">{group.activePositionCount} active</Badge>
                    </div>
                  </div>
                  <div className="grid gap-3 text-sm text-muted-foreground sm:grid-cols-3">
                    <StatLine label="Liquidity" value={formatAmount(group.totalLiquidity)} />
                    <StatLine label="Fees" value={formatAmount(group.totalFees)} />
                    <StatLine label="PnL" value={formatSignedAmount(group.totalPnl)} positive={group.totalPnl >= 0n} />
                  </div>
                </CardHeader>
              </summary>
              <CardContent className="space-y-3 border-t border-border/70 bg-background/40 pt-4">
                {group.positions.map((position) => (
                  <div key={position.positionId} className="rounded-2xl border border-border/70 bg-background/80 p-4">
                    <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                      <div>
                        <div className="font-medium">
                          Position range [{position.tickLower}, {position.tickUpper}]
                        </div>
                        <div className="font-mono text-xs text-muted-foreground">{shortenHash(position.positionId)}</div>
                      </div>
                      <Badge variant={position.active ? "default" : "outline"}>
                        {position.active ? "Active" : "Inactive"}
                      </Badge>
                    </div>
                    <div className="mt-3 grid gap-3 text-sm sm:grid-cols-3">
                      <StatLine label="Liquidity" value={formatAmount(position.liquidity)} />
                      <StatLine label="Fees" value={formatAmount(position.fees)} />
                      <StatLine label="PnL" value={formatSignedAmount(position.netPnl)} positive={position.netPnl >= 0n} />
                    </div>
                  </div>
                ))}
              </CardContent>
            </Card>
          </details>
        ))}
      </div>
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
