# Deployment and settlement runbook

## Before deployment

1. Pin the audited v2-protocol commit and check it contains the final `SingletonFixedTermHooks` implementation.
2. Check the approved hooks template, hooks factory and singleton role-provider factory addresses.
3. Check that Wildcat accepts the settlement asset, then record its address and decimals.
4. Check the standard Ethereum mainnet Chainlink BTC/USD proxy, `description()` and `decimals()` against Chainlink's current directory.
5. Freeze the series manifest, legal terms, note transfer policy, maturity, oracle delay and fallback procedure.
6. Run unit, fuzz, stateful accounting-property and mainnet-fork tests against the pinned commits.

## Deploy the series

1. Choose the market salt and calculate the expected market address through `HooksFactory.computeMarketAddress`.
2. Deploy a non-upgradeable `BRCNoteVault` bound to the expected address.
3. Open subscriptions. Enforce the notional cap and funding deadline.
4. Close funding or enable refunds if the minimum raise was missed.
5. Encode one zero-TTL singleton provider with the vault as lender. Do not supply an existing provider or a second one.
6. Encode the fixed-term hook data as five complete ABI words:

```solidity
abi.encode(
  uint32(maturity),
  uint128(0),
  true,   // transfersDisabled
  false,  // allowClosureBeforeTerm
  false   // allowTermReduction
);
```

7. Request deposit and transfer dispatch. Leave raw withdrawal access false. The fixed-term parent adds the queue, close and APR/reserve-ratio dispatch it requires.
8. Call `deployMarketAndHooks` from the registered borrower account.

## Verify before moving funds

Check the market address, asset, borrower, supply cap, APR, reserve ratio, maturity and hook address. Then check that provider configuration is sealed, there is one pull provider and no push provider, and the provider's lender is the vault with a zero TTL.

Read `getHookedMarket` and check deposit access, transfer access, disabled market-token transfers, disabled early closure and disabled term reduction. Try an unrelated deposit, market-token transfer, pre-maturity close, repricing, term reduction and provider mutation. Every call should revert.

Check the vault bytecode, series manifest hash, note supply, funding total, feed metadata and expected market address.

## Activate

1. Read a fresh BTC/USD round and store `S0` once.
2. Calculate `K = S0` and the barrier from the manifest.
3. Approve exactly the funded notional to the market.
4. Deposit it from the vault.
5. Remove the remaining approval.
6. Enter `Active` and emit the full fixing and activation record.

## During the term

Keep an eye on the Chainlink feed, proxy phase, deprecation notices, market liquidity, delinquency, protocol-fee changes, the vault's sanctions status and the maturity transaction path. Rehearse the maturity and fallback calls on a fork before the observation time.

## At maturity

1. Submit the first valid BTC/USD round at or after maturity together with the evidence required to prove its position in the proxy history.
2. Store `ST` once.
3. Queue the vault's complete market balance for withdrawal.
4. Have the borrower fund and close the Wildcat market.
5. Execute the withdrawal after its batch expires.
6. Confirm that the market is closed and that the vault collected its complete claim.
7. Calculate the slash and transfer the borrower rebate.
8. Open pro-rata note redemption against the remaining USDC.

If the market does not perform in full, enter recovery. Do not pay the borrower rebate.
