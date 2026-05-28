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
anvil
```

Start the UI:

```bash
npm run dev
```

Open http://localhost:3000.

The UI reads unlocked Anvil accounts from `http://127.0.0.1:8545` by default.
Override that RPC URL with:

```bash
NEXT_PUBLIC_ANVIL_RPC_URL=http://127.0.0.1:8545 npm run dev
```

## Current Slice

- Lists default funded Anvil accounts.
- Displays ETH balances.
- Lets you select a sender account.
- Sends a simple ETH transfer between Anvil accounts as the test transaction.
