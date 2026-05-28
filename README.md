# Squid

Monorepo for Squid smart contracts and the local simulation UI.

## Architecture

Squid is split into two top-level projects:

```text
squid/
  contracts/   # Foundry project
  ui/          # Next.js simulator UI
```

The smart contracts remain a standalone Foundry project under `contracts/`.
The simulator UI is a separate Next.js app under `ui/`. Shared runtime data,
such as future local deployment addresses, should live at the repo root or in a
dedicated root-level `deployments/` directory instead of being embedded in
either app.

Foundry commands should generally be run from the repo root with `--root
contracts`. This lets Foundry load the root `.env` while still using
`contracts/foundry.toml`.

## Tech Stack

### Contracts

- **Solidity** for Squid and supporting libraries.
- **Foundry** for build, test, fork testing, formatting, Anvil, and contract
  scripting.
- **Uniswap v4 hook dependencies** via the `v4-hooks-public` submodule.
- **Anvil** for deterministic local Ethereum simulation.

### UI

- **Next.js + TypeScript** for the simulator application.
- **shadcn/ui** for application controls, forms, cards, tables, and layout
  primitives.
- **Tremor** for dashboard-style metrics.
- **TanStack Query** for polling and caching chain state.
- **TanStack Table** for account, pool, LP, and position tables.
- **viem** for JSON-RPC reads and unlocked Anvil account transactions.

### Docker

- **Docker Compose** is used for local orchestration.
- The default Compose stack runs Anvil and the UI.
- A separate `contracts` Compose service can run Foundry tests in Docker.

## Architecture Decisions

- **Monorepo with separate apps:** contracts and UI are intentionally separated
  so Solidity tooling, frontend dependencies, and build outputs do not overlap.
- **Foundry stays primary:** Hardhat is not introduced because the repo is
  already Foundry-native and the existing tests define the simulation setup.
- **Anvil accounts first:** the first UI slice uses Anvil's default unlocked
  funded accounts instead of browser-generated burner wallets. This keeps local
  signing deterministic and avoids key-management complexity while the simulator
  is being built.
- **Simple ETH transfer as first transaction:** the initial UI validates account
  selection, balance reads, transaction submission, receipt waiting, and balance
  refresh before adding Squid/Uniswap-specific flows.
- **Browser RPC URL points to localhost:** the UI uses
  `NEXT_PUBLIC_ANVIL_RPC_URL`, defaulting to `http://127.0.0.1:8545`, because
  contract calls are made from the browser, not from the Next.js server.
- **Root `.env` is canonical:** fork tests and future shared scripts should
  read environment values from the repo root. Use root npm scripts instead of
  `cd contracts && forge test` when `.env` values are required.
- **Docker is dev-focused for now:** Compose is useful for one-command local
  startup, but the contracts Docker context still needs optimization before it
  should be treated as polished CI infrastructure.

## Contracts

Run Foundry commands from the repo root so Foundry can load the root `.env`:

```shell
npm run contracts:build
npm run contracts:test
```

Run only fork tests:

```shell
npm run contracts:test:fork
```

If you run directly from `contracts/`, export the root env first:

```shell
set -a
source ../.env
set +a
forge test
```

Start a local chain from any directory:

```shell
anvil
```

## UI

Run the simulator UI from `ui/`:

```shell
cd ui
npm install
npm run dev
```

Open http://localhost:3000.

The current UI reads Anvil's default unlocked accounts from
`http://127.0.0.1:8545`, displays balances, lets you select a sender, and sends
a simple ETH transfer as a test transaction.

## Docker

Run Anvil and the UI together:

```shell
npm run docker:up
```

Open http://localhost:3000.

Stop the stack:

```shell
npm run docker:down
```

Run Foundry tests in Docker:

```shell
npm run docker:contracts:test
```
