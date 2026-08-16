# Deployment and settlement runbook

## Before deployment

1. Pin the reviewed v2-protocol candidate and check it contains the intended `SingletonFixedTermHooks` implementation. The current research pin is the head of an open PR, not a final or audited release. Record the exact review or audit artefact that would justify changing that status before deployment.
2. Check the approved hooks template, hooks factory and singleton role-provider factory addresses. Record the Wildcat ArchController owner, SphereX admin, operator and current engine; these are trust inputs, and the engine can change later. Record the template's fee recipient and protocol fee as well.
3. Check that Wildcat accepts the settlement asset, then record its address and decimals.
4. Check the standard Ethereum mainnet Chainlink BTC/USD proxy, `description()` and `decimals()` against Chainlink's current directory.
5. Freeze the series manifest, legal terms, note transfer policy, maturity, oracle delay,
   `recoveryDelay` and write-off time. Check that the recovery start, withdrawal duration and the
   extra second Wildcat may need when closing a batch all fit below its 32-bit timestamp limit. Do
   not confuse `recoveryDelay` with Wildcat's separate `delinquencyGracePeriod`.
6. Record the fallback source identifier, waiting and challenge periods, ratifier addresses and threshold. Ratifiers must be distinct ECDSA EOAs; Safe and other contract-wallet signers are not supported by this prototype. The signing procedure must bind the chain, oracle, series, proposal, price, observation time, evidence hash and source.
7. Run unit, fuzz, stateful accounting-property and mainnet-fork tests against the pinned commits.

## Deploy the series

Start with the dry-run and verification commands in [`deployment-tooling.md`](deployment-tooling.md). Keep the wallet key and RPC credentials out of the manifest and deployment record.

1. Deploy a `BRCBorrowerAccount` through an account factory approved by the Wildcat identity registry, then register it against the borrower principal.
2. Choose the vault and market salts. Check that both start with the operational borrower account address, then calculate the expected market through `HooksFactory.computeMarketAddress`.
3. Read the current BTC/USD proxy round. Build the non-upgradeable `BRCNoteVault` creation bytecode bound to the manifest hash and expected market, then calculate its borrower-scoped CREATE2 address.
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

7. Request deposit and transfer dispatch. The fixed-term parent forces queue, close and
   APR/reserve-ratio hook dispatch on. Keep the separate hooked-market field
   `withdrawalRequiresAccess` false so queueing is not credential-gated.
8. Have the borrower principal call the operational borrower account. The account checks the shared hook nonce, deploys the vault and calls `deployMarketAndHooks` atomically. Any changed nonce, principal or address reverts the whole transaction.
9. Keep the generated record with the approved manifest. It contains the readable manifest, ABI encoding, manifest hash, calculated addresses and deployed code hashes.

## Verify before moving funds

Run the read-only verifier against the approved manifest and generated record. Do not fund unless it exits successfully.

Check the market address, asset, operational borrower, registered borrower principal, empty pending-borrower slot, supply cap, APR, reserve ratio, delinquency fee, delinquency grace period, withdrawal-batch duration, fee recipient, activation-time protocol fee, maturity and hook address. Confirm that the hook administrator is the registered principal. Then check that provider configuration is sealed, there is one pull provider and no push provider, and the provider's lender is the vault with a zero TTL.

Read `getHookedMarket` and check deposit access, transfer access, disabled market-token transfers, disabled early closure and disabled term reduction. Try an unrelated deposit, market-token transfer, pre-maturity close, repricing, term reduction and provider mutation. Every call should revert.

Check the vault bytecode, series manifest hash, stored `S0`, feed metadata and expected market address. Read back the recovery dates and every fallback ratifier, then match the threshold, source and delays to the manifest. Confirm each ratifier has no deployed code and verify one series-domain rehearsal signature from every address. Re-read the ArchController's SphereX admin, operator and engine, and check that the market reports that engine. Wildcat permits borrower succession and SphereX engine changes after activation. Write both down as live legal, credit and governance assumptions; they are not frozen onchain terms.

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

1. Queue the vault's complete market balance immediately, before the safe queue deadline and without waiting for `ST`. If `nukeFromOrbit` got there first and queued the sanctioned vault, supply that authenticated batch expiry and adopt it.
2. In parallel, submit the first valid BTC/USD round at or after maturity together with the evidence required to prove its position in the proxy history.
3. Store `ST` once, using the primary route or the delayed fallback procedure below.
4. Have the borrower fund the Wildcat claim and close the market where practical.
5. Execute the withdrawal after its batch expires.
6. Confirm that the vault collected its complete claim. Formal closure of the empty market is not required for settlement.
7. Call `finalizeSettlement()` to calculate and reserve the borrower rebate and noteholder pool.
   The borrower then calls `claimBorrowerRebate()`, which pays only the principal fixed at deployment.
8. Open pro-rata note redemption against the remaining settlement assets.

If the queued claim remains partly unpaid after `maturity + recoveryDelay`, enter recovery. Do not
pay the borrower rebate. Missing the safe queue deadline leaves the vault unable to reach
`Withdrawing` or `Recovery`; escalate that operational failure under the transaction and legal
fallback plan rather than pretending the onchain recovery path remains available.

## If the primary fixing is unavailable

1. Wait until the maximum Chainlink observation delay and the additional fallback waiting period have both ended.
2. Check once more whether the primary proof can be supplied. The contract cannot prove that a valid but unsubmitted Chainlink round does not exist.
3. Have one immutable ratifier propose the fallback price, observation time, fixed source identifier and evidence hash.
4. Publish the underlying evidence somewhere the signatures and hash can be checked later.
5. Collect signatures from the immutable ratifier set. Any ratifier may veto the proposal during or after the challenge period, up to finalisation.
6. If a valid primary proof appears before finalisation, submit it; it cancels the pending fallback.
7. Once the challenge period has ended and the threshold has signed, finalise the fallback once.

## If the market defaults

1. Queue the complete position at or after maturity; this does not require the BTC fixing. Include any authenticated pre-existing batch expiries.
2. Wait until `maturity + recoveryDelay`. If the queued claim remains partly unpaid, call
   `enterRecovery()`. A fully paid claim cannot enter recovery. A valid BTC fixing does not change
   the default path and no borrower rebate is available there.
3. As Wildcat pays a batch, execute the available withdrawal into the vault. Redemptions stay closed while recoveries are still coming in.
4. At or after the fixed write-off eligibility time, check that every recorded batch has expired, then call `finalizeRecovery()`. It executes any amount Wildcat has made withdrawable before taking the snapshot.
5. Open note redemption against the recovered pool. The call is permissionless; later Wildcat payments and unsolicited transfers do not enlarge the pool.
