# Architecture

## Contracts

`BRCNoteVault` owns the one direct Wildcat lender position. Investors own note tokens issued by the vault; they never receive Wildcat market tokens.

`BtcUsdFixingOracle` records the initial and maturity observations. It reads the standard Chainlink BTC/USD proxy and stores each accepted fixing once.

`SingletonFixedTermHooks` keeps the Wildcat side plain. It admits the vault, seals the provider list, prevents pre-maturity closure and term reduction, and freezes APR and reserve ratio before maturity.

```text
investors
    | subscribe for notes
    v
BRCNoteVault ------ sole lender ------> Wildcat market ------> borrower
    |
    +------ reads fixed observations ------> BtcUsdFixingOracle
```

## Boundaries

Wildcat accounts for ordinary USDC debt, lender interest, liquidity and delinquency. It does not know what a BRC is.

The vault accounts for subscriptions, note supply, the market position, the slash, borrower rebate and investor redemptions.

The oracle adapter decides whether a Chainlink round matches the observation rule. It does not custody assets or calculate note redemptions.

The canonical Wildcat 4626 wrapper is not used. A pass-through wrapper cannot apply the BRC waterfall, and allowing the vault's market tokens to move creates a route the product does not need. The market therefore sets `transfersDisabled = true`.

## Trust

One immutable vault is deployed for each series. It has no delegatecall, general executor, market-token approval route or administrative asset sweep.

An upgradeable vault would leave the lender address fixed while allowing its behaviour to change. This design does not use one.

The oracle fallback is delayed and challengeable. No administrator receives an immediate price-setting function.

## Lifecycle

```text
Funding -> Active -> Withdrawing -> Settled -> Redeemable
                    |
                    +-------------> Recovery
```

Funding may end in cancellation if the minimum raise is missed. Active fixes `S0` and deposits the notional. Withdrawing fixes `ST` and queues the complete Wildcat position. Settled is available only after full performance. Recovery holds partial proceeds without paying a borrower rebate.

