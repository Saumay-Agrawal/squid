"use client";
import { useMemo, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { DashboardData } from "@/lib/simulation";
import { formatAmount, formatToken, shortenAddress, shortenHash } from "@/lib/utils";

export function PositionsView({ data }: { data: DashboardData }) {
  const [pool, setPool] = useState("all"); const [status, setStatus] = useState("all");
  const rows = useMemo(() => data.positions.filter((p) => (pool === "all" || p.poolIndex === Number(pool)) && (status === "all" || (status === "active") === p.active)), [data.positions, pool, status]);
  return <Card><CardHeader><CardTitle>Liquidity positions</CardTitle><CardDescription>Token-specific principal, fees, and PnL; unlike-unit values are not aggregated.</CardDescription>
    <div className="flex flex-wrap gap-2 pt-2"><Filter values={["all", ...data.pools.map((p) => String(p.index))]} active={pool} set={setPool} label={(v) => v === "all" ? "All pools" : `Pool ${Number(v)+1}`} />
      <Filter values={["all", "active", "inactive"]} active={status} set={setStatus} /></div>
  </CardHeader><CardContent className="overflow-x-auto"><Table><TableHeader><TableRow>
    <TableHead>Position</TableHead><TableHead>LP</TableHead><TableHead>Status / range</TableHead><TableHead>Liquidity</TableHead>
    <TableHead>{data.market.token0Symbol} PnL</TableHead><TableHead>{data.market.token1Symbol} PnL</TableHead><TableHead>Fees</TableHead>
  </TableRow></TableHeader><TableBody>{rows.map((row) => <TableRow key={row.positionId}>
    <TableCell><div>{row.label}</div><div className="font-mono text-xs text-muted-foreground">{shortenHash(row.positionId)}</div></TableCell>
    <TableCell className="font-mono text-xs">{shortenAddress(row.lp)}</TableCell><TableCell><Badge variant={row.active ? "default" : "secondary"}>{row.active ? "Active" : "Inactive"}</Badge><div className="text-xs text-muted-foreground">[{row.tickLower}, {row.tickUpper})</div></TableCell>
    <TableCell>{formatAmount(row.activeLiquidity)}<div className="text-xs text-muted-foreground">of {formatAmount(row.totalLiquidity)}</div></TableCell>
    <TableCell className={row.netPnl0 >= 0n ? "text-emerald-600" : "text-rose-600"}>{formatToken(row.netPnl0, data.market.token0Decimals, data.market.token0Symbol)}</TableCell>
    <TableCell className={row.netPnl1 >= 0n ? "text-emerald-600" : "text-rose-600"}>{formatToken(row.netPnl1, data.market.token1Decimals, data.market.token1Symbol)}</TableCell>
    <TableCell><div>{formatToken(row.feeAccumulated0, data.market.token0Decimals, data.market.token0Symbol)}</div><div>{formatToken(row.feeAccumulated1, data.market.token1Decimals, data.market.token1Symbol)}</div></TableCell>
  </TableRow>)}</TableBody></Table></CardContent></Card>;
}
function Filter({ values, active, set, label = (v) => v }: { values: string[]; active: string; set: (v: string) => void; label?: (v: string) => string }) {
  return <div className="flex flex-wrap gap-2">{values.map((v) => <Button key={v} size="sm" variant={active === v ? "default" : "outline"} onClick={() => set(v)} className="capitalize">{label(v)}</Button>)}</div>;
}
