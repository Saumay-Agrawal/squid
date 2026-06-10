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

export type TokenDisplayConfig = {
  symbol: string;
  decimals: number;
};

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function shortenHex(value?: string) {
  if (!value) return "N/A";
  if (value.length <= 8) return value;
  return `${value.slice(0, 5)}...${value.slice(-3)}`;
}

export function shortenAddress(value?: string) {
  if (!value) return "No wallet";
  return shortenHex(value);
}

export function shortenHash(value: string) {
  return shortenHex(value);
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

export function formatRatioPercent(numerator: bigint, denominator: bigint) {
  if (denominator === 0n) {
    return "0.00%";
  }

  const basisPoints = Number((numerator * 10_000n) / denominator);
  return formatBps(basisPoints);
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

export function formatTokenBalance(value: bigint, decimals: number) {
  const negative = value < 0n;
  const absolute = negative ? -value : value;
  const base = 10n ** BigInt(decimals);
  const whole = absolute / base;
  const fraction = (absolute % base).toString().padStart(decimals, "0").slice(0, 4).replace(/0+$/, "");
  const wholeText = whole.toLocaleString("en-US");
  const sign = negative ? "-" : "";

  return fraction ? `${sign}${wholeText}.${fraction}` : `${sign}${wholeText}`;
}

export function formatSignedTokenBalance(value: bigint, decimals: number) {
  if (value === 0n) {
    return "0";
  }

  return value > 0n ? `+${formatTokenBalance(value, decimals)}` : formatTokenBalance(value, decimals);
}

export function formatTokenAmountParts(value: bigint, decimals: number): FormattedAmountParts {
  return {
    primary: formatTokenBalance(value, decimals),
    secondary: null,
  };
}

export function formatSignedTokenAmountParts(value: bigint, decimals: number): FormattedAmountParts {
  return {
    primary: formatSignedTokenBalance(value, decimals),
    secondary: null,
  };
}

export function formatTokenPairWithDecimals(
  token0: TokenDisplayConfig,
  value0: bigint,
  token1: TokenDisplayConfig,
  value1: bigint,
) {
  return {
    primary: `${token0.symbol} ${formatTokenBalance(value0, token0.decimals)} / ${token1.symbol} ${formatTokenBalance(value1, token1.decimals)}`,
    secondary: null,
  };
}

export function formatSignedTokenPairWithDecimals(
  token0: TokenDisplayConfig,
  value0: bigint,
  token1: TokenDisplayConfig,
  value1: bigint,
) {
  return {
    primary: `${token0.symbol} ${formatSignedTokenBalance(value0, token0.decimals)} / ${token1.symbol} ${formatSignedTokenBalance(value1, token1.decimals)}`,
    secondary: null,
  };
}

export function classifyDualTokenSign(value0: bigint, value1: bigint) {
  const nonNegative = value0 >= 0n && value1 >= 0n;
  const nonPositive = value0 <= 0n && value1 <= 0n;

  if (nonNegative && (value0 > 0n || value1 > 0n)) {
    return true;
  }

  if (nonPositive && (value0 < 0n || value1 < 0n)) {
    return false;
  }

  return undefined;
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
