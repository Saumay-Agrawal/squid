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
    <div className="space-y-5">
      <Card className="overflow-hidden border-primary/10 bg-card/88 shadow-lg shadow-primary/5">
        <CardHeader className="gap-5">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <CardTitle className="text-xl">{selectedLabel ?? profile.label}</CardTitle>
                <Badge>You</Badge>
              </div>
              <CardDescription>{shortenAddress(profile.address)}</CardDescription>
            </div>
            <Badge variant="secondary">{profile.poolCount} pools</Badge>
          </div>
          <div className="grid gap-3 text-sm sm:grid-cols-2 xl:grid-cols-4">
            <StatLine label="Positions" value={String(profile.positionCount)} />
            <StatLine label="Active" value={String(profile.activePositionCount)} />
            <StatLine label="Liquidity" value={formatAmount(profile.totalLiquidity)} />
            <StatLine label="Net PnL" value={formatSignedAmount(profile.totalPnl)} positive={profile.totalPnl >= 0n} />
          </div>
        </CardHeader>
        <CardContent className="grid gap-3 border-t border-border/70 bg-background/35 pt-5 sm:grid-cols-3">
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
            value={formatAmount(profile.totalFees)}
            note="Total accrued fees across all grouped positions."
          />
        </CardContent>
      </Card>

      <div className="grid gap-4">
        {profile.groups.map((group) => (
          <Card key={`${profile.address}-${group.poolId}`} className="overflow-hidden">
            <CardHeader className="gap-4">
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
              <div className="grid gap-3 text-sm sm:grid-cols-3">
                <StatLine label="Liquidity" value={formatAmount(group.totalLiquidity)} />
                <StatLine label="Fees" value={formatAmount(group.totalFees)} />
                <StatLine label="PnL" value={formatSignedAmount(group.totalPnl)} positive={group.totalPnl >= 0n} />
              </div>
            </CardHeader>
            <CardContent className="grid gap-3 border-t border-border/70 bg-background/35 pt-4">
              {group.positions.map((position) => (
                <div key={position.positionId} className="rounded-3xl border border-border/70 bg-background/80 p-4">
                  <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                    <div>
                      <div className="font-medium">
                        Position range [{position.tickLower}, {position.tickUpper}]
                      </div>
                      <div className="mt-1 font-mono text-xs text-muted-foreground">{shortenHash(position.positionId)}</div>
                    </div>
                    <Badge variant={position.active ? "default" : "outline"} className={position.active ? "bg-emerald-600 text-white" : ""}>
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
    <div className="flex items-center justify-between gap-4 rounded-2xl border border-border/60 bg-background/70 px-3 py-3">
      <span className="text-muted-foreground">{label}</span>
      <span className={positive === undefined ? "font-medium" : positive ? "font-medium text-emerald-600 dark:text-emerald-400" : "font-medium text-rose-600 dark:text-rose-400"}>
        {value}
      </span>
    </div>
  );
}

function FocusBlock({ title, value, note }: { title: string; value: string; note: string }) {
  return (
    <div className="rounded-3xl border border-border/70 bg-card/70 p-4">
      <div className="text-xs uppercase tracking-[0.16em] text-muted-foreground">{title}</div>
      <div className="mt-2 text-2xl font-semibold tracking-[-0.03em]">{value}</div>
      <div className="mt-1 text-sm text-muted-foreground">{note}</div>
    </div>
  );
}
