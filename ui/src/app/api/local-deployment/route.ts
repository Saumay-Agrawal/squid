import { readFile } from "node:fs/promises";
import path from "node:path";

import { NextResponse } from "next/server";

import { parseLocalDeploymentArtifact } from "@/lib/local-deployment";

const candidatePaths = [
  path.join(process.cwd(), "..", "deployments", "local-anvil.json"),
  path.join(process.cwd(), "..", "contracts", "deployments", "local-anvil.json"),
  path.join(process.cwd(), "deployments", "local-anvil.json"),
];

export async function GET() {
  for (const filePath of candidatePaths) {
    try {
      const contents = await readFile(filePath, "utf8");
      return NextResponse.json(
        parseLocalDeploymentArtifact(JSON.parse(contents)),
      );
    } catch (error) {
      if (error instanceof Error && !("code" in error)) {
        return NextResponse.json({ error: error.message }, { status: 500 });
      }
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
        return NextResponse.json(
          { error: "Failed to read local deployment artifact." },
          { status: 500 },
        );
      }
    }
  }

  return NextResponse.json(
    { error: "Local deployment artifact not found." },
    { status: 404 },
  );
}
