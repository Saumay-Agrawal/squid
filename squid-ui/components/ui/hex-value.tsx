"use client";

import { Copy, Check } from "lucide-react";
import { useEffect, useId, useRef, useState } from "react";
import { createPortal } from "react-dom";

import { Button } from "@/components/ui/button";
import { cn, shortenHex } from "@/lib/utils";

export function HexValue({
  value,
  className,
  textClassName,
  side = "top",
  prefix,
}: {
  value: string;
  className?: string;
  textClassName?: string;
  side?: "top" | "bottom";
  prefix?: string;
}) {
  const tooltipId = useId();
  const triggerRef = useRef<HTMLSpanElement | null>(null);
  const tooltipRef = useRef<HTMLSpanElement | null>(null);
  const closeTimeoutRef = useRef<number | null>(null);
  const [open, setOpen] = useState(false);
  const [copied, setCopied] = useState(false);
  const [mounted, setMounted] = useState(false);
  const [position, setPosition] = useState({ top: 0, left: 0 });

  useEffect(() => {
    setMounted(true);
  }, []);

  useEffect(() => {
    return () => {
      if (closeTimeoutRef.current !== null) {
        window.clearTimeout(closeTimeoutRef.current);
      }
    };
  }, []);

  useEffect(() => {
    if (!copied) {
      return undefined;
    }

    const timeout = window.setTimeout(() => setCopied(false), 1_500);
    return () => window.clearTimeout(timeout);
  }, [copied]);

  useEffect(() => {
    if (!open || !triggerRef.current) {
      return undefined;
    }

    function updatePosition() {
      if (!triggerRef.current) {
        return;
      }

      const rect = triggerRef.current.getBoundingClientRect();
      setPosition({
        left: rect.left + (rect.width / 2),
        top: side === "top" ? rect.top - 2 : rect.bottom + 2,
      });
    }

    updatePosition();
    window.addEventListener("scroll", updatePosition, true);
    window.addEventListener("resize", updatePosition);

    return () => {
      window.removeEventListener("scroll", updatePosition, true);
      window.removeEventListener("resize", updatePosition);
    };
  }, [open, side]);

  async function handleCopy() {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(true);
    } catch {
      setCopied(false);
    }
  }

  function moveWithinInteractiveSurface(nextTarget: EventTarget | null) {
    return nextTarget instanceof Node && (
      triggerRef.current?.contains(nextTarget) ||
      tooltipRef.current?.contains(nextTarget)
    );
  }

  function clearCloseTimeout() {
    if (closeTimeoutRef.current !== null) {
      window.clearTimeout(closeTimeoutRef.current);
      closeTimeoutRef.current = null;
    }
  }

  function scheduleClose() {
    clearCloseTimeout();
    closeTimeoutRef.current = window.setTimeout(() => {
      setOpen(false);
      closeTimeoutRef.current = null;
    }, 180);
  }

  return (
    <span
      ref={triggerRef}
      className={cn("inline-flex items-center", className)}
      tabIndex={0}
      aria-describedby={open ? tooltipId : undefined}
      onMouseEnter={() => {
        clearCloseTimeout();
        setOpen(true);
      }}
      onMouseLeave={(event) => {
        if (!moveWithinInteractiveSurface(event.relatedTarget)) {
          scheduleClose();
        }
      }}
      onFocus={() => {
        clearCloseTimeout();
        setOpen(true);
      }}
      onBlur={(event) => {
        if (!moveWithinInteractiveSurface(event.relatedTarget)) {
          scheduleClose();
        }
      }}
    >
      <span className={cn("font-mono", textClassName)}>
        {prefix ? `${prefix} ${shortenHex(value)}` : shortenHex(value)}
      </span>
      {mounted && open ? createPortal(
        <span
          ref={tooltipRef}
          id={tooltipId}
          role="tooltip"
          className={cn(
            "fixed z-[10000] min-w-56 rounded-xl border border-border/80 bg-popover px-3 py-2 text-left text-xs leading-5 text-popover-foreground shadow-2xl",
            side === "top" ? "-translate-x-1/2 -translate-y-full" : "-translate-x-1/2"
          )}
          style={{ left: position.left, top: position.top }}
          onMouseEnter={() => {
            clearCloseTimeout();
            setOpen(true);
          }}
          onMouseLeave={(event) => {
            if (!moveWithinInteractiveSurface(event.relatedTarget)) {
              scheduleClose();
            }
          }}
        >
          <div className="space-y-2">
            <div className="break-all font-mono text-[11px] leading-4">{value}</div>
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="h-7 w-full justify-center gap-1.5 text-[11px]"
              onClick={handleCopy}
            >
              {copied ? <Check className="h-3.5 w-3.5" /> : <Copy className="h-3.5 w-3.5" />}
              {copied ? "Copied" : "Copy"}
            </Button>
          </div>
        </span>,
        document.body,
      ) : null}
    </span>
  );
}
