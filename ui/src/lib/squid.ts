"use client";

import { type Address, type Hex, getAddress } from "viem";

import { publicClient } from "@/lib/anvil";
import {
  parseLocalDeploymentArtifact,
  type LocalDeploymentArtifact,
} from "@/lib/local-deployment";

const squidAddressOverride = process.env.NEXT_PUBLIC_SQUID_ADDRESS
  ? getAddress(process.env.NEXT_PUBLIC_SQUID_ADDRESS)
  : null;

export const squidAbi = [
  {
    type: "function",
    name: "getPoolCount",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "getPoolSummaries",
    stateMutability: "view",
    inputs: [
      { name: "offset", type: "uint256" },
      { name: "limit", type: "uint256" },
    ],
    outputs: [
      {
        name: "",
        type: "tuple[]",
        components: [
          { name: "poolId", type: "bytes32" },
          { name: "currency0", type: "address" },
          { name: "currency1", type: "address" },
          { name: "fee", type: "uint24" },
          { name: "tickSpacing", type: "int24" },
          { name: "initializedAtBlock", type: "uint256" },
          { name: "activeLpCount", type: "uint256" },
          { name: "activePositionCount", type: "uint256" },
          { name: "trackedLiquidity", type: "uint128" },
          { name: "swapCount", type: "uint256" },
        ],
      },
    ],
  },
] as const;

export type PoolSummary = {
  poolId: Hex;
  currency0: Address;
  currency1: Address;
  fee: number;
  tickSpacing: number;
  initializedAtBlock: bigint;
  activeLpCount: bigint;
  activePositionCount: bigint;
  trackedLiquidity: bigint;
  swapCount: bigint;
};

export type SquidDeployment = Partial<LocalDeploymentArtifact> & {
  squidAddress: Address;
  source: "env" | "artifact" | "env+artifact";
};

export async function getSquidDeployment(): Promise<SquidDeployment> {
  const response = await fetch("/api/local-deployment", { cache: "no-store" });

  if (!response.ok) {
    if (squidAddressOverride) {
      return {
        squidAddress: squidAddressOverride,
        source: "env",
      };
    }
    throw new Error("Run the local Anvil seed script or set NEXT_PUBLIC_SQUID_ADDRESS.");
  }

  const artifact = parseLocalDeploymentArtifact(await response.json());
  const artifactAddress = getAddress(artifact.squidAddress);

  return {
    ...artifact,
    squidAddress: squidAddressOverride ?? artifactAddress,
    source: squidAddressOverride ? "env+artifact" : "artifact",
  };
}

export async function getPoolCount(squidAddress: Address): Promise<number> {
  const count = await publicClient.readContract({
    address: squidAddress,
    abi: squidAbi,
    functionName: "getPoolCount",
  });

  return Number(count);
}

export async function getPoolSummaries(
  squidAddress: Address,
  offset: number,
  limit: number,
): Promise<PoolSummary[]> {
  const summaries = await publicClient.readContract({
    address: squidAddress,
    abi: squidAbi,
    functionName: "getPoolSummaries",
    args: [BigInt(offset), BigInt(limit)],
  });

  return [...summaries];
}
