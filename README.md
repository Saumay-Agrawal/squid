## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Local Squid Simulation

Run the local Squid simulation harness and persist the result artifact:

```shell
$ anvil
$ forge script script/SimulateSquid.s.sol:SimulateSquid --rpc-url http://127.0.0.1:8545 --sig "simulate()"
```

For a Foundry-local dry run without an RPC node:

```shell
$ forge script --offline script/SimulateSquid.s.sol:SimulateSquid --sig "simulate()"
```

This writes a machine-readable artifact to `script/output/anvil-simulation.json`.

The simulation currently includes:

- multiple locally deployed token pairs and pools
- liquidity positions opened from distinct LP addresses
- swaps and liquidity removals to exercise Squid pool and position metrics
- persisted deployed contract addresses, chronological scenario actions, and final pool/position snapshots

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
