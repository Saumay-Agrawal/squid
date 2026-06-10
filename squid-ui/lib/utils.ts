import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

const READABLE_AMOUNT_THRESHOLD = 1_000_000n;
const READABLE_SCALES = [
  { threshold: 1_000_000_000_000_000_000_000_000_000_000_000n, label: "decillion" },
  { threshold: 1_000_000_000_000_000_000_000_000_000_000n, label: "nonillion" },
  { threshold: 1_000_000_000_000_000_000_000_000_000n, label: "octillion" },
  { threshold: 1_000_000_000_000_000_000_000_000n, label: "septillion" },
  { threshold: 1_000_000_000_000_000_000_000n, label: "sextillion" },
  { threshold: 1_000_000_000_000_000_000n, label: "quintillion" },
  { threshold: 1_000_000_000_000_000n, label: "quadrillion" },
  { threshold: 1_000_000_000_000n, label: "trillion" },
  { threshold: 1_000_000_000n, label: "billion" },
  { threshold: 1_000_000n, label: "million" },
] as const;

export type FormattedAmountParts = {
  primary: string;
  secondary: string | null;
};

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

export function formatBps(value: number) {
  return `${(value / 100).toFixed(2)}%`;
}

export function formatAmount(value: bigint) {
  return value.toLocaleString("en-US");
}

export function formatSignedAmount(value: bigint) {
  if (value === 0n) return "0";
  return value > 0n ? `+${formatAmount(value)}` : formatAmount(value);
}

export function formatReadableAmount(value: bigint) {
  return formatReadableScale(value, false);
}

export function formatSignedReadableAmount(value: bigint) {
  return formatReadableScale(value, true);
}

export function formatAmountParts(value: bigint): FormattedAmountParts {
  return {
    primary: formatAmount(value),
    secondary: formatReadableAmount(value),
  };
}

export function formatSignedAmountParts(value: bigint): FormattedAmountParts {
  return {
    primary: formatSignedAmount(value),
    secondary: formatSignedReadableAmount(value),
  };
}

export function startCase(value: string) {
  return value
    .split(/[-_\s]+/)
    .filter(Boolean)
    .map((segment) => `${segment.slice(0, 1).toUpperCase()}${segment.slice(1)}`)
    .join(" ");
}

export function formatTokenPair(label0: string, value0: bigint, label1: string, value1: bigint) {
  return `${label0} ${formatAmount(value0)} / ${label1} ${formatAmount(value1)}`;
}

export function formatCompactTokenPair(label0: string, value0: bigint, label1: string, value1: bigint) {
  const left = formatAmountParts(value0);
  const right = formatAmountParts(value1);
  return {
    primary: `${label0} ${left.primary} / ${label1} ${right.primary}`,
    secondary:
      left.secondary || right.secondary
        ? `${label0} ${left.secondary ?? left.primary} / ${label1} ${right.secondary ?? right.primary}`
        : null,
  };
}

export function formatBlock(value: number) {
  return value.toLocaleString("en-US");
}

export function formatTimestamp(value: number) {
  return new Date(value * 1000).toLocaleString("en-US", {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

function formatReadableScale(value: bigint, signed: boolean) {
  const negative = value < 0n;
  const absolute = negative ? -value : value;

  if (absolute < READABLE_AMOUNT_THRESHOLD) {
    return null;
  }

  const scale = READABLE_SCALES.find((candidate) => absolute >= candidate.threshold);

  if (!scale) {
    return null;
  }

  const whole = absolute / scale.threshold;
  const fraction = ((absolute % scale.threshold) * 1_000n) / scale.threshold;
  const fractionText = fraction.toString().padStart(3, "0").replace(/0+$/, "");
  const magnitude = fractionText ? `${whole.toString()}.${fractionText}` : whole.toString();
  const sign = negative ? "-" : signed && value > 0n ? "+" : "";

  return `${sign}${magnitude} ${scale.label}`;
}
