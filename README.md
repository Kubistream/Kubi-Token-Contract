## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

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

## Environment Variables

Populate the following keys in your `.env` file before running the deployment scripts. Leave any per-token override unset if you want to inherit the protocol default.

- `PRIVATE_KEY`
- `DEFAULT_UNDERLYING_TOKEN`
- `DEFAULT_VAULT_ADDRESS`
- `DEFAULT_DEPOSITOR_CONTRACT`

> Note: Vault and depositor addresses are configured once per protocol; individual token overrides are not used.

### Morpho Defaults
- `MORPHO_DEFAULT_UNDERLYING`
- `MORPHO_DEFAULT_VAULT`
- `MORPHO_DEFAULT_DEPOSITOR`

### Morpho Token Overrides
- `MORPHO_USDC_UNDERLYING`
- `MORPHO_USDT_UNDERLYING`
- `MORPHO_IDRX_UNDERLYING`
- `MORPHO_BTC_UNDERLYING`
- `MORPHO_ETH_UNDERLYING`

### Aero Defaults
- `AERO_DEFAULT_UNDERLYING`
- `AERO_DEFAULT_VAULT`
- `AERO_DEFAULT_DEPOSITOR`

### Aero Token Overrides
- `AERO_USDC_UNDERLYING`
- `AERO_USDT_UNDERLYING`
- `AERO_IDRX_UNDERLYING`
- `AERO_BTC_UNDERLYING`
- `AERO_ETH_UNDERLYING`

### Aave Defaults
- `AAVE_DEFAULT_UNDERLYING`
- `AAVE_DEFAULT_VAULT`
- `AAVE_DEFAULT_DEPOSITOR`

### Aave Token Overrides
- `AAVE_USDC_UNDERLYING`
- `AAVE_USDT_UNDERLYING`
- `AAVE_IDRX_UNDERLYING`
- `AAVE_BTC_UNDERLYING`
- `AAVE_ETH_UNDERLYING`

### Compound Defaults
- `COMPOUND_DEFAULT_UNDERLYING`
- `COMPOUND_DEFAULT_VAULT`
- `COMPOUND_DEFAULT_DEPOSITOR`

### Compound Token Overrides
- `COMPOUND_USDC_UNDERLYING`
- `COMPOUND_USDT_UNDERLYING`
- `COMPOUND_IDRX_UNDERLYING`
- `COMPOUND_BTC_UNDERLYING`
- `COMPOUND_ETH_UNDERLYING`
