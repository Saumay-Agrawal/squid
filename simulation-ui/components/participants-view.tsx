"use client";
import { useState } from "react";
import { Users } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import type { DashboardData } from "@/lib/simulation";
import { formatToken, shortenAddress } from "@/lib/utils";

export function ParticipantsView({ data }: { data: DashboardData }) {
  const [role, setRole] = useState<"All" | "LP" | "Trader">("All");
  const rows = data.participants.filter((row) => role === "All" || row.role === role);
  return <Card><CardHeader className="gap-4 lg:flex-row lg:items-end lg:justify-between"><div>
    <CardTitle className="flex items-center gap-2"><Users className="h-5 w-5" />Participants</CardTitle>
    <CardDescription>Seed personas and planned versus observed activity.</CardDescription></div>
    <div className="flex gap-2">{(["All", "LP", "Trader"] as const).map((value) =>
      <Button key={value} size="sm" variant={role === value ? "default" : "outline"} onClick={() => setRole(value)}>{value}</Button>)}</div>
  </CardHeader><CardContent className="overflow-x-auto"><Table><TableHeader><TableRow>
    <TableHead>Participant</TableHead><TableHead>Role</TableHead><TableHead>Strategy</TableHead>
    <TableHead>Activity</TableHead><TableHead>Seeded ETH</TableHead><TableHead>Seeded USDC</TableHead>
  </TableRow></TableHeader><TableBody>{rows.map((row) => <TableRow key={row.address}>
    <TableCell><div className="font-medium">{row.label}</div><div className="font-mono text-xs text-muted-foreground">{shortenAddress(row.address)}</div></TableCell>
    <TableCell><Badge variant={row.role === "LP" ? "default" : "secondary"}>{row.role}</Badge></TableCell>
    <TableCell><div>{row.strategy}</div>{row.tier && <div className="text-xs text-muted-foreground">{row.tier}{row.anchor ? " · anchor" : ""}</div>}</TableCell>
    <TableCell>{row.actualActivity} / {row.plannedActivity}</TableCell>
    <TableCell>{formatToken(row.seededEth, 18, "ETH")}</TableCell><TableCell>{formatToken(row.seededUsdc, 6, "USDC")}</TableCell>
  </TableRow>)}</TableBody></Table></CardContent></Card>;
}
