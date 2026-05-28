# Squid Simulator UI

Next.js dashboard for local Squid protocol simulation.

## Stack

- Next.js + TypeScript
- shadcn/ui
- Tremor
- TanStack Query
- TanStack Table
- viem

## Local Development

Start Anvil from another terminal:

```bash
anvil --disable-code-size-limit
```

Seed a local Squid deployment and pools from the repo root:

```bash
npm run contracts:seed:anvil
```

If the root npm script is flaky, run the seed command from inside `contracts/`:

```bash
cd ../contracts
forge script script/SeedLocalAnvil.s.sol:SeedLocalAnvilScript \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --always-use-create-2-factory \
  -vvvv
cd ../ui
```

Validate the generated artifact:

```bash
npm run deployment:validate
```

Start the UI:

```bash
npm run dev
```

Open http://localhost:3000.

The UI reads unlocked Anvil accounts from `http://127.0.0.1:8545` by default.
It also reads `../contracts/deployments/local-anvil.json` through a local API
route to discover the seeded Squid contract. Override the RPC URL with:

```bash
NEXT_PUBLIC_ANVIL_RPC_URL=http://127.0.0.1:8545 npm run dev
```

## Current Slice

- Lists current Squid pools from the seeded local deployment.
- Reads unlocked Anvil accounts for wallet context.
- Shows a sidebar shell with Pools and Profile tabs.

## Gotchas

- If the UI shows `Unable to load pools` and `getPoolCount` returns `0x`, the
  current `squidAddress` artifact points at an account with no contract code.
  Rerun the local seed flow and validate the artifact again.
- Do not start Anvil without `--disable-code-size-limit` for this setup.
- The deployment artifact is generated from the contracts project, so the UI
  depends on the seed step having completed successfully first.

## TODOs

- Move artifact discovery to a shared root-level deployment location.
- Add a frontend health check that surfaces the loaded Squid address and whether
  bytecode exists there before attempting pool reads.
