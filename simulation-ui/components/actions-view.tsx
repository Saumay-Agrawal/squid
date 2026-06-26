"use client";
import { useMemo, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { DashboardData } from "@/lib/simulation";
import { formatAmount, shortenHash } from "@/lib/utils";

export function ActionsView({ data }: { data: DashboardData }) {
  const [phase, setPhase] = useState("all");
  const phases = useMemo(() => ["all", ...new Set(data.actions.map((a) => a.phase))], [data.actions]);
  const rows = data.actions.filter((action) => phase === "all" || action.phase === phase);
  return <Card><CardHeader><CardTitle>Action timeline</CardTitle><CardDescription>Ordered execution records; each row maps to one historical checkpoint.</CardDescription>
    <div className="flex flex-wrap gap-2 pt-2">{phases.map((value) => <Button key={value} size="sm" variant={phase === value ? "default" : "outline"} onClick={() => setPhase(value)} className="capitalize">{value}</Button>)}</div>
  </CardHeader><CardContent className="overflow-x-auto"><Table><TableHeader><TableRow>
    <TableHead>#</TableHead><TableHead>Phase</TableHead><TableHead>Action</TableHead><TableHead>Actor</TableHead>
    <TableHead>Pool</TableHead><TableHead>Amount</TableHead><TableHead>Position</TableHead>
  </TableRow></TableHeader><TableBody>{rows.map((row) => <TableRow key={row.sequence}>
    <TableCell>{row.sequence}</TableCell><TableCell><Badge variant="secondary">{row.phase}</Badge></TableCell>
    <TableCell className="capitalize">{row.actionType.replaceAll("-", " ")}</TableCell><TableCell>{row.actor}</TableCell>
    <TableCell>{row.poolIndex === 255 ? "—" : `Pool ${row.poolIndex + 1}`}</TableCell>
    <TableCell>{row.actionType === "swap" ? `${row.zeroForOne ? "0 → 1" : "1 → 0"} ${formatAmount(BigInt(row.amountSpecified))}` : formatAmount(BigInt(row.liquidityDelta))}</TableCell>
    <TableCell className="font-mono text-xs">{/^0x0+$/.test(row.positionId) ? "—" : shortenHash(row.positionId)}</TableCell>
  </TableRow>)}</TableBody></Table></CardContent></Card>;
}
