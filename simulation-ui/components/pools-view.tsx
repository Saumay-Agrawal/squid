import { Activity, ArrowRightLeft, Droplets, TrendingUp } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { MetricCard } from "@/components/ui/metric-card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { DashboardData } from "@/lib/simulation";
import { formatAmount, formatBps, formatFeeTier, formatTick, formatToken, shortenHash } from "@/lib/utils";

export function PoolsView({ data }: { data: DashboardData }) {
  const active = data.pools.reduce((sum, row) => sum + row.activeLiquidity, 0n);
  const total = data.pools.reduce((sum, row) => sum + row.totalLiquidity, 0n);
  return <div className="space-y-4">
    <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
      <MetricCard title="Pools" value={String(data.pools.length)} note="Tracked fee tiers" icon={Droplets} />
      <MetricCard title="Total liquidity" value={formatAmount(total)} note="Final tracked liquidity" icon={Activity} />
      <MetricCard title="Active liquidity" value={formatAmount(active)} note="Final in-range liquidity" icon={TrendingUp} />
      <MetricCard title="Swaps" value={String(data.pools.reduce((sum, p) => sum + p.totalSwapCount, 0))} note="Across every pool" icon={ArrowRightLeft} />
    </section>
    <Card><CardHeader><CardTitle>Pool board</CardTitle><CardDescription>Final state with utilization, participation, and flow metrics.</CardDescription></CardHeader>
      <CardContent className="overflow-x-auto"><Table><TableHeader><TableRow>
        <TableHead>Pool</TableHead><TableHead>Fee / tick</TableHead><TableHead>Utilization</TableHead><TableHead>Liquidity</TableHead>
        <TableHead>LPs</TableHead><TableHead>Positions</TableHead><TableHead>Flow</TableHead><TableHead>Pool ID</TableHead>
      </TableRow></TableHeader><TableBody>{data.pools.map((pool) => <TableRow key={pool.poolId}>
        <TableCell><div className="font-medium">{pool.label}</div><Badge variant="secondary">{pool.tokenPair}</Badge></TableCell>
        <TableCell>{formatFeeTier(pool.fee)}<div className="text-xs text-muted-foreground">{pool.tickSpacing} spacing · {formatTick(pool.tick)}</div></TableCell>
        <TableCell>{formatBps(pool.liquidityUtilisationBps)}<div className="text-xs text-muted-foreground">peak {formatBps(pool.peakLiquidityUtilisationBps)}</div></TableCell>
        <TableCell>{formatAmount(pool.activeLiquidity)}<div className="text-xs text-muted-foreground">of {formatAmount(pool.totalLiquidity)}</div></TableCell>
        <TableCell>{pool.activeLpCount} / {pool.lifetimeLpCount}</TableCell><TableCell>{pool.activePositionCount} / {pool.totalPositionCount}</TableCell>
        <TableCell>{pool.zeroToOneSwapCount} / {pool.oneToZeroSwapCount}<div className="text-xs text-muted-foreground">{formatBps(pool.flowSkewnessBps)} skew</div></TableCell>
        <TableCell className="font-mono text-xs">{shortenHash(pool.poolId)}</TableCell>
      </TableRow>)}</TableBody></Table></CardContent></Card>
    <div className="grid gap-4 xl:grid-cols-2">{data.pools.map((pool) => <Card key={`${pool.poolId}-balances`}><CardHeader><CardTitle className="text-base">{pool.label} balances</CardTitle></CardHeader>
      <CardContent className="grid gap-3 text-sm sm:grid-cols-2">
        <Info label="Current ETH" value={formatToken(pool.currentToken0Amount, data.market.token0Decimals, data.market.token0Symbol)} />
        <Info label="Current USDC" value={formatToken(pool.currentToken1Amount, data.market.token1Decimals, data.market.token1Symbol)} />
        <Info label="Fees ETH" value={formatToken(pool.totalFeeAccruedToken0, data.market.token0Decimals, data.market.token0Symbol)} />
        <Info label="Fees USDC" value={formatToken(pool.totalFeeAccruedToken1, data.market.token1Decimals, data.market.token1Symbol)} />
      </CardContent></Card>)}</div>
  </div>;
}
function Info({ label, value }: { label: string; value: string }) { return <div><div className="text-muted-foreground">{label}</div><div className="font-medium">{value}</div></div>; }
