import type { LucideIcon } from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

export function MetricCard({ title, value, note, icon: Icon }: {
  title: string; value: string; note: string; icon: LucideIcon;
}) {
  return (
    <Card>
      <CardHeader className="flex flex-row items-start justify-between space-y-0">
        <div><CardDescription>{title}</CardDescription><CardTitle className="mt-2 text-2xl">{value}</CardTitle></div>
        <div className="rounded-2xl bg-primary/10 p-3 text-primary"><Icon className="h-4 w-4" /></div>
      </CardHeader>
      <CardContent className="text-sm text-muted-foreground">{note}</CardContent>
    </Card>
  );
}
