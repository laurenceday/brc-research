# Task 10: add deployment and verification tooling

Status: implemented and merged. This step turns one reviewed manifest into deterministic vault, oracle, hook, provider and Wildcat market addresses, then reads the deployment back from chain.

## Manifest shipped

`BRCSeriesManifest` records:

- chain, environment, repository commits and compiler settings;
- vault terms, note transfer policy, factory, salt and code hash;
- borrower identity, market terms, fees, recovery dates and dependencies;
- hook template, singleton provider factory, deployment nonce and salts;
- BTC/USD feed identity, observation rule and fallback configuration; and
- ArchController and SphereX governance state.

The canonical ABI encoding is hashed into the vault. The deployment record retains the readable manifest, its encoded form, the manifest hash, deployed addresses and runtime code hashes.

## Deterministic deployment shipped

The registered `BRCBorrowerAccount` performs vault creation and `deployMarketAndHooks` in one transaction. Both vault and market salts begin with that account address. The account checks its current principal, hook nonce, template fees and governance before and after vault deployment, approves only the exact origination fee when one exists, and clears that allowance afterwards.

The hook input contains one new zero-TTL singleton provider, no existing provider and the vault as lender. Fixed-term data is exactly five ABI words:

```solidity
abi.encode(
  uint32(maturity),
  uint128(0),
  true,   // transfersDisabled
  false,  // allowClosureBeforeTerm
  false   // allowTermReduction
)
```

Deposit and transfer access are requested. Queue-withdrawal hook dispatch is enabled by the fixed-term template, while `withdrawalRequiresAccess` remains false.

There is no mutable market setter. Counterfactual addresses are resolved through the documented CREATE2 calculation order.

## Verification shipped

`script/deploy-brc.sh` checks the repository revisions, clean checkouts, Foundry profile and remappings before it runs the Solidity deployment script. It rejects command-line options that could swap the build inputs or expose a raw private key or mnemonic.

`VerifyBRC` is the pre-funding readback. It checks the manifest, record, addresses, code hashes, vault immutables, market policy, hook configuration, provider seal and lender, feed metadata, initial fixing and governance state. The vault's own `_validateActivationPolicy` runs later, inside `activate()`, after funding has finalised and before the vault deposits. There is no pre-funding vault call that performs that acceptance check.

The verifier is script-side code and is too large for EIP-170 deployment.

## Evidence

`test/BRCDeployment.t.sol` covers local deterministic deployment, address reproduction, exact singleton and fixed-term inputs, stale principal nonce, changed template fees, counterfeit vault initcode, salt ownership, deployment authority, JSON narrowing and mutation of every manifest and record field checked by the verifier.

The opt-in mainnet fork test checks the live Ethereum BTC/USD proxy and deploys the pinned factory and template artefacts on the fork. It is not evidence of an approved production deployment.

## Boundary of this step

`config/series.example.json` remains a template with zero addresses, zero hashes, zero timestamps and a placeholder BRC commit. It cannot approve or deploy a real series unchanged. A release still needs reviewed live addresses, a signed manifest, a deployment record and independent verifier output.
