# Deployment and settlement runbook

## Before deployment

1. Pin the audited v2-protocol commit and check it contains the final `SingletonFixedTermHooks` implementation.
2. Check the approved hooks template, hooks factory and singleton role-provider factory addresses. Record the Wildcat ArchController owner, SphereX admin, operator and current engine; these are trust inputs, and the engine can change later. Record the template's fee recipient and protocol fee as well.
3. Check that Wildcat accepts the settlement asset, then record its address and decimals.
4. Check the standard Ethereum mainnet Chainlink BTC/USD proxy, `description()` and `decimals()` against Chainlink's current directory.
5. Freeze the series manifest, legal terms, note transfer policy, maturity, oracle delay and fallback procedure. Check that the maturity, maximum observation delay, withdrawal duration and the extra second Wildcat may need when closing a batch all fit below its 32-bit timestamp limit.
6. Run unit, fuzz, stateful accounting-property and mainnet-fork tests against the pinned commits.

## Deploy the series

1. Choose the market salt and calculate the expected market address through `HooksFactory.computeMarketAddress`.
2. Check that the salt starts with the operational borrower address. Record the operational borrower and its registered principal separately.
3. Read the current BTC/USD proxy round, then deploy a non-upgradeable `BRCNoteVault` bound to the expected market. Deployment stores `S0`, the strike and the barrier before subscriptions open.
4. Encode one zero-TTL singleton provider with the vault as lender. Do not supply an existing provider or a second one.
5. Record the provider factory's deployed runtime code hash in the manifest.
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
8. Call `deployMarketAndHooks` from the operational borrower account.

## Verify before moving funds

Check the market address, asset, operational borrower, registered borrower principal, empty pending-borrower slot, supply cap, APR, reserve ratio, delinquency fee, delinquency grace period, withdrawal-batch duration, fee recipient, activation-time protocol fee, maturity and hook address. Confirm that the hook administrator is the registered principal. Then check that provider configuration is sealed, there is one pull provider and no push provider, and the provider's lender is the vault with a zero TTL.

Read `getHookedMarket` and check deposit access, transfer access, disabled market-token transfers, disabled early closure and disabled term reduction. Try an unrelated deposit, market-token transfer, pre-maturity close, repricing, term reduction and provider mutation. Every call should revert.

Check the vault bytecode, series manifest hash, stored `S0`, feed metadata and expected market address. Re-read the ArchController's SphereX admin, operator and engine, and check that the market reports that engine. Wildcat permits borrower succession and SphereX engine changes after activation. Write both down as live legal, credit and governance assumptions; they are not frozen onchain terms.

## Fund the series

1. Only after the market and hook checks pass, open note eligibility and subscriptions.
2. Enforce the notional cap and funding deadline.
3. Finalise a full raise. If the minimum raise is missed, cancel funding and enable refunds.
4. Recheck note supply, vault backing and the complete manifest before activation.

## Activate

1. Read the already stored `S0`, strike and barrier from the vault's oracle.
2. Re-run every live market, hook, provider and borrower-identity check.
3. Before the activation deadline, call permissionless `activate()`.
4. Confirm that the vault approved and deposited exactly the notional, removed the remaining approval and entered `Active`.
5. Match the activation event's market, hook, provider and stored fixing to the manifest.

If activation never succeeds, call `cancelUnactivated()` at the activation deadline and let current noteholders refund. A failed activation does not replace or erase `S0`.

## During the term

Keep an eye on the Chainlink feed, proxy phase, deprecation notices, market liquidity, delinquency, protocol-fee changes, the vault's sanctions status, the ArchController owner, the SphereX admin, operator and engine, and the maturity transaction path. The ArchController owner can raise the fee to 1,000 bips and push it to the active market. Treat any fee, SphereX role or engine change as a reason to repeat the recovery and withdrawal-path rehearsal. Rehearse the maturity and fallback calls on a fork before the observation time.

## At maturity

1. Submit the first valid BTC/USD round at or after maturity together with the evidence required to prove its position in the proxy history.
2. Store `ST` once.
3. Queue the vault's complete market balance before the safe queue deadline. If `nukeFromOrbit` got there first and queued the sanctioned vault, supply that authenticated batch expiry and adopt it.
4. Have the borrower fund and close the Wildcat market.
5. Execute the withdrawal after its batch expires.
6. Confirm that the market is closed and that the vault collected its complete claim.
7. Calculate the slash and transfer the borrower rebate.
8. Open pro-rata note redemption against the remaining USDC.

If the market does not perform in full, or the safe queue deadline has passed, enter recovery. Do not pay the borrower rebate.
