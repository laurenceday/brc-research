# Architecture

## Contracts

`BRCNoteVault` owns the only direct Wildcat lender position. Investors get note tokens from the vault, never Wildcat market tokens.

`BtcUsdFixingOracle` records the initial and maturity observations. It reads the standard Chainlink BTC/USD proxy and stores each accepted fixing once, full stop.

`SingletonFixedTermHooks` keeps the Wildcat side plain. It admits the vault, seals the provider list, blocks early closure and term reduction, and freezes the APR and reserve ratio until maturity.

```text
investors
    | subscribe for notes
    v
BRCNoteVault ------ sole lender ------> Wildcat market ------> borrower
    |
    +------ reads fixed observations ------> BtcUsdFixingOracle
```

## Boundaries

Wildcat accounts for ordinary USDC debt, lender interest, liquidity and delinquency. It has no idea what a BRC is.

The vault accounts for subscriptions, note supply, the market position, the slash, the borrower rebate and investor redemptions.

The oracle adapter decides whether a Chainlink round fits the observation rule. It does not hold assets or work out note redemptions.

We do not use the canonical Wildcat 4626 wrapper. A pass-through wrapper cannot apply the BRC waterfall, and there is no reason for the vault's market tokens to move. The market sets `transfersDisabled = true`.

## Trust

Each series gets one immutable vault. It has no delegatecall, general executor, market-token approval route or admin asset sweep.

An upgradeable vault would keep the lender address fixed while letting its behaviour change underneath it, so this design does not use one.

The oracle fallback has a delay and a challenge period. Nobody gets an instant admin price setter.

## Lifecycle

```text
Funding -> Funded -> Active -> Withdrawing -> Redeemable -> Settled
   |          |          |
   v          v          +---> Recovery (task 9)
Cancelled  Cancelled
```

The configured vault fixes `S0` during deployment, before funding. Funding can end in cancellation if the minimum raise is missed, and a funded series can also cancel if activation never succeeds. Active deposits the notional against that precommitted fixing. Withdrawing fixes `ST` and queues the whole Wildcat position. Full performance opens `Redeemable`; `Settled` is terminal and arrives only after the rebate and every note redemption are complete. Task 9 adds recovery for partial proceeds, with no borrower rebate.
