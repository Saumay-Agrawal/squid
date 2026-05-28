import { type Address, type Hex, getAddress } from "viem";

export type LocalDeploymentArtifact = {
  chainId: number;
  rpcUrl: string;
  deployer: Address;
  squidAddress: Address;
  poolManagerAddress: Address;
  usdcAddress: Address;
  wethAddress: Address;
  seededPoolIds: Hex[];
  seededPoolFees: number[];
  seededPoolTickSpacings: number[];
};

function expectObject(value: unknown, context: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${context} must be an object.`);
  }

  return value as Record<string, unknown>;
}

function expectString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`${field} must be a non-empty string.`);
  }

  return value;
}

function expectNumber(value: unknown, field: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new Error(`${field} must be a finite number.`);
  }

  return value;
}

function expectAddress(value: unknown, field: string): Address {
  return getAddress(expectString(value, field));
}

function expectHexArray(value: unknown, field: string): Hex[] {
  if (!Array.isArray(value)) {
    throw new Error(`${field} must be an array.`);
  }

  return value.map((entry, index) => {
    const hex = expectString(entry, `${field}[${index}]`);
    if (!hex.startsWith("0x")) {
      throw new Error(`${field}[${index}] must be a hex string.`);
    }
    return hex as Hex;
  });
}

function expectNumberArray(value: unknown, field: string): number[] {
  if (!Array.isArray(value)) {
    throw new Error(`${field} must be an array.`);
  }

  return value.map((entry, index) => expectNumber(entry, `${field}[${index}]`));
}

export function parseLocalDeploymentArtifact(
  value: unknown,
): LocalDeploymentArtifact {
  const object = expectObject(value, "Local deployment artifact");

  const artifact: LocalDeploymentArtifact = {
    chainId: expectNumber(object.chainId, "chainId"),
    rpcUrl: expectString(object.rpcUrl, "rpcUrl"),
    deployer: expectAddress(object.deployer, "deployer"),
    squidAddress: expectAddress(object.squidAddress, "squidAddress"),
    poolManagerAddress: expectAddress(
      object.poolManagerAddress,
      "poolManagerAddress",
    ),
    usdcAddress: expectAddress(object.usdcAddress, "usdcAddress"),
    wethAddress: expectAddress(object.wethAddress, "wethAddress"),
    seededPoolIds: expectHexArray(object.seededPoolIds, "seededPoolIds"),
    seededPoolFees: expectNumberArray(object.seededPoolFees, "seededPoolFees"),
    seededPoolTickSpacings: expectNumberArray(
      object.seededPoolTickSpacings,
      "seededPoolTickSpacings",
    ),
  };

  if (
    artifact.seededPoolIds.length !== artifact.seededPoolFees.length ||
    artifact.seededPoolIds.length !== artifact.seededPoolTickSpacings.length
  ) {
    throw new Error(
      "seededPoolIds, seededPoolFees, and seededPoolTickSpacings must have matching lengths.",
    );
  }

  if (artifact.seededPoolIds.length === 0) {
    throw new Error("seededPoolIds must not be empty.");
  }

  return artifact;
}
