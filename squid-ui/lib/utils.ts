import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function shortenAddress(value?: string) {
  if (!value) return "No wallet";
  return `${value.slice(0, 6)}...${value.slice(-4)}`;
}

export function shortenHash(value: string) {
  return `${value.slice(0, 10)}...${value.slice(-6)}`;
}

export function formatTick(value: number) {
  return new Intl.NumberFormat("en-US", { signDisplay: "exceptZero" }).format(value);
}

export function formatFeeTier(value: number) {
  return `${(value / 10_000).toFixed(2)}%`;
}

export function formatAmount(value: bigint) {
  const negative = value < 0n;
  const absolute = negative ? -value : value;
  const text = absolute.toString();

  if (text.length <= 6) return `${negative ? "-" : ""}${text}`;

  const units = [
    { threshold: 1_000_000_000_000n, suffix: "T" },
    { threshold: 1_000_000_000n, suffix: "B" },
    { threshold: 1_000_000n, suffix: "M" },
    { threshold: 1_000n, suffix: "K" },
  ];

  for (const unit of units) {
    if (absolute >= unit.threshold) {
      const whole = absolute / unit.threshold;
      const fraction = (absolute % unit.threshold) / (unit.threshold / 10n);
      return `${negative ? "-" : ""}${whole.toString()}.${fraction.toString()}${unit.suffix}`;
    }
  }

  return `${negative ? "-" : ""}${text}`;
}

export function formatSignedAmount(value: bigint) {
  if (value === 0n) return "0";
  return `${value > 0n ? "+" : "-"}${formatAmount(value > 0n ? value : -value)}`;
}

export function startCase(value: string) {
  return value
    .split(/[-_\s]+/)
    .filter(Boolean)
    .map((segment) => `${segment.slice(0, 1).toUpperCase()}${segment.slice(1)}`)
    .join(" ");
}
