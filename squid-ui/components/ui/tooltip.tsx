"use client";

import * as React from "react";

import { cn } from "@/lib/utils";

function Tooltip({
  content,
  children,
  className,
  side = "top",
}: {
  content: React.ReactNode;
  children: React.ReactNode;
  className?: string;
  side?: "top" | "bottom";
}) {
  return (
    <span className={cn("group/tooltip relative inline-flex", className)} tabIndex={-1}>
      {children}
      <span
        role="tooltip"
        className={cn(
          "pointer-events-none absolute left-1/2 z-50 hidden w-56 -translate-x-1/2 rounded-xl border border-border/80 bg-popover px-3 py-2 text-left text-xs leading-5 text-popover-foreground shadow-lg",
          side === "top" ? "bottom-full mb-2" : "top-full mt-2",
          "group-hover/tooltip:block group-focus-within/tooltip:block"
        )}
      >
        {content}
      </span>
    </span>
  );
}

export { Tooltip };
