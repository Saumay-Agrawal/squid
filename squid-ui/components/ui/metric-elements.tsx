"use client";

import { CircleHelp } from "lucide-react";

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Tooltip } from "@/components/ui/tooltip";
import { cn } from "@/lib/utils";

function MetricHeader({ label, tooltip }: { label: string; tooltip: string }) {
  return <MetricLabel label={label} tooltip={tooltip} tooltipSide="bottom" className="font-medium text-foreground/90" />;
}

function MetricLabel({
  label,
  tooltip,
  className,
  tooltipSide = "top",
}: {
  label: string;
  tooltip: string;
  className?: string;
  tooltipSide?: "top" | "bottom";
}) {
  return (
    <span className={cn("inline-flex items-center gap-1.5 text-sm text-muted-foreground", className)}>
      <span>{label}</span>
      <Tooltip content={tooltip} side={tooltipSide}>
        <button
          type="button"
          aria-label={`What ${label.toLowerCase()} means`}
          className="inline-flex h-4 w-4 items-center justify-center rounded-full text-muted-foreground transition hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        >
          <CircleHelp className="h-3.5 w-3.5" />
        </button>
      </Tooltip>
    </span>
  );
}

function GroupedMetricsCard({
  title,
  description,
  metrics,
}: {
  title: string;
  description: string;
  metrics: Array<{
    label: string;
    value: string;
    detail?: string | null;
    tooltip: string;
    mono?: boolean;
    positive?: boolean;
  }>;
}) {
  return (
    <Card className="border-border/60 bg-background/70 shadow-none">
      <CardHeader className="pb-4">
        <CardTitle className="text-base">{title}</CardTitle>
        <CardDescription>{description}</CardDescription>
      </CardHeader>
      <CardContent className="grid gap-3 sm:grid-cols-2 xl:grid-cols-1">
        {metrics.map((metric) => (
          <StatLine key={metric.label} {...metric} />
        ))}
      </CardContent>
    </Card>
  );
}

function StatLine({
  label,
  value,
  detail,
  tooltip,
  positive,
  mono = false,
}: {
  label: string;
  value: string;
  detail?: string | null;
  tooltip: string;
  positive?: boolean;
  mono?: boolean;
}) {
  return (
    <div className="flex items-center justify-between gap-4 rounded-2xl border border-border/60 bg-background/80 px-3 py-3">
      <MetricLabel label={label} tooltip={tooltip} />
      <div className="text-right">
        <div
          className={cn(
            mono ? "font-mono text-xs" : "font-medium",
            positive === undefined ? "" : positive ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"
          )}
        >
          {value}
        </div>
        {detail ? <div className="text-xs text-muted-foreground">{detail}</div> : null}
      </div>
    </div>
  );
}

function MetricStack({
  primary,
  secondary,
  emphasize = false,
}: {
  primary: string;
  secondary: string;
  emphasize?: boolean;
}) {
  return (
    <div>
      <div className={cn("font-medium", emphasize ? "text-emerald-600 dark:text-emerald-400" : "")}>{primary}</div>
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

export { GroupedMetricsCard, MetricHeader, MetricLabel, MetricStack, PnlValue, StatLine };
