# Task 10: add deployment and verification tooling

## Aim

Turn an approved series manifest into reproducible vault, hook, provider and Wildcat market deployments, then prove that the resulting addresses and stored policy match the manifest.

## Manifest

Use one machine-readable manifest containing:

- chain ID and deployment environment;
- pinned repository commits and compiler settings;
- borrower, settlement asset and BTC/USD proxy;
- notional, minimum raise, funding deadline and maturity;
- APR, reserve ratio, delinquency settings and market cap;
- strike and barrier convention;
- oracle timing, fallback quorum and challenge periods;
- note transfer policy; and
- approved factory and template addresses.

Hash the canonical encoding and bind the vault deployment to that hash. Write the human-readable and encoded forms to the deployment record.

## Address calculation and deployment

1. Check bytecode and expected code hashes for every approved factory and template.
2. Choose the Wildcat market salt and calculate the market address through `HooksFactory.computeMarketAddress`.
3. Calculate or deploy the vault bound to that expected market.
4. Encode `SingletonFixedTermHooksInputs` with exactly one new zero-TTL singleton provider, no existing provider, and the vault as lender in both outer and factory inputs.
5. Encode fixed-term data as exactly 160 bytes:

```solidity
abi.encode(
  uint32(maturity),
  uint128(0),
  true,   // transfersDisabled
  false,  // allowClosureBeforeTerm
  false   // allowTermReduction
)
```

6. Enable deposit and transfer dispatch. Leave raw queue-withdrawal access false.
7. Call `deployMarketAndHooks` from the registered borrower account.
8. Run the vault acceptance checker before opening or finalising funding, according to the chosen deployment order.

Where counterfactual addresses create circular constructor inputs, document the salt derivation and calculation order. Do not resolve the cycle by adding a mutable market setter to the vault.

## Verifier

Add a read-only command that accepts a manifest and deployment record, then checks code, addresses, immutable values, hook policy, provider seal, provider lender, feed metadata and market configuration. It must exit non-zero on any mismatch and print the failing field.

## Exercises

- Local deterministic deployment from an empty chain.
- Mainnet fork using the approved factory and feed addresses.
- A second run proving the same salts and bytecode produce the same addresses.
- One mutation test for every manifest field checked by the verifier.
- Dry-run output suitable for borrower and reviewer sign-off before broadcast.

## Acceptance

- A reviewer can reproduce every calculated address from the committed record.
- Dependency revisions and code hashes are printed before broadcast.
- The verifier passes on the recorded deployment and fails on altered data.
- No deployment script retains an unlimited settlement-asset approval.
- Secrets, private keys and RPC credentials never enter the record or command output.
