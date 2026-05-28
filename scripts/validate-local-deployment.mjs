import { readFile } from "node:fs/promises";
import path from "node:path";

const artifactPaths = [
  path.join(process.cwd(), "deployments", "local-anvil.json"),
  path.join(process.cwd(), "contracts", "deployments", "local-anvil.json"),
];

function expectObject(value, context) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${context} must be an object.`);
  }
  return value;
}

function expectString(value, field) {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`${field} must be a non-empty string.`);
  }
  return value;
}

function expectNumber(value, field) {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new Error(`${field} must be a finite number.`);
  }
  return value;
}

function expectArray(value, field) {
  if (!Array.isArray(value)) {
    throw new Error(`${field} must be an array.`);
  }
  return value;
}

function expectAddress(value, field) {
  const address = expectString(value, field);
  if (!/^0x[a-fA-F0-9]{40}$/.test(address)) {
    throw new Error(`${field} must be a 20-byte hex address.`);
  }
}

function expectBytes32(value, field) {
  const hex = expectString(value, field);
  if (!/^0x[a-fA-F0-9]{64}$/.test(hex)) {
    throw new Error(`${field} must be a 32-byte hex string.`);
  }
}

async function main() {
  let contents;
  let artifactPath;

  for (const candidatePath of artifactPaths) {
    try {
      contents = await readFile(candidatePath, "utf8");
      artifactPath = candidatePath;
      break;
    } catch (error) {
      if (
        !error ||
        typeof error !== "object" ||
        !("code" in error) ||
        error.code !== "ENOENT"
      ) {
        throw error;
      }
    }
  }

  if (!contents || !artifactPath) {
    throw new Error(
      `Missing local deployment artifact. Run 'npm run contracts:seed:anvil' first.`,
    );
  }

  const artifact = expectObject(JSON.parse(contents), "Local deployment artifact");

  expectNumber(artifact.chainId, "chainId");
  expectString(artifact.rpcUrl, "rpcUrl");
  expectAddress(artifact.deployer, "deployer");
  expectAddress(artifact.squidAddress, "squidAddress");
  expectAddress(artifact.poolManagerAddress, "poolManagerAddress");
  expectAddress(artifact.usdcAddress, "usdcAddress");
  expectAddress(artifact.wethAddress, "wethAddress");

  const seededPoolIds = expectArray(artifact.seededPoolIds, "seededPoolIds");
  const seededPoolFees = expectArray(artifact.seededPoolFees, "seededPoolFees");
  const seededPoolTickSpacings = expectArray(
    artifact.seededPoolTickSpacings,
    "seededPoolTickSpacings",
  );

  if (
    seededPoolIds.length === 0 ||
    seededPoolIds.length !== seededPoolFees.length ||
    seededPoolIds.length !== seededPoolTickSpacings.length
  ) {
    throw new Error(
      "seededPoolIds, seededPoolFees, and seededPoolTickSpacings must be non-empty and have matching lengths.",
    );
  }

  seededPoolIds.forEach((value, index) =>
    expectBytes32(value, `seededPoolIds[${index}]`),
  );
  seededPoolFees.forEach((value, index) =>
    expectNumber(value, `seededPoolFees[${index}]`),
  );
  seededPoolTickSpacings.forEach((value, index) =>
    expectNumber(value, `seededPoolTickSpacings[${index}]`),
  );

  console.log(`Validated ${artifactPath}`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
