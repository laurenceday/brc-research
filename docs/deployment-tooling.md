# Deployment tooling

One JSON manifest goes in. The deployment command prints the addresses and dependency hashes for review, deploys the vault and Wildcat market, then writes a JSON record. The verifier reads the manifest and record back from chain; a mismatch gives a non-zero exit and names the first bad field.

This is a working prototype. The operational borrower is a registered `BRCBorrowerAccount`; its registered principal signs the deployment. The account makes vault creation and `deployMarketAndHooks` one transaction, so a change to the principal-wide hook nonce reverts before the market salt is consumed. The same account can forward later borrower calls from its principal.

## Fill the manifest

Copy `config/series.example.json` and replace every zero address, zero hash, zero timestamp and `SET_...` value. Keep amounts in settlement-asset base units and times as Unix seconds.

The manifest is the complete input to `keccak256(abi.encode(manifest))`. The vault stores that hash. The deployment record contains both the readable manifest and its ABI encoding, so a reviewer can reproduce the hash without trusting either command.

Before the dry run, check the following against the selected chain:

- the hooks factory, singleton fixed-term template, singleton provider factory and BTC/USD proxy code hashes;
- the borrower account, identity registry and vault factory code hashes;
- the template fee recipient, protocol fee, origination fee asset and origination fee amount;
- the hook deployment nonce for the registered borrower principal;
- BTC/USD `description()` and `decimals()`;
- the ArchController owner, SphereX admin, pending admin, operator and current engine; and
- the exact repository commits and compiler settings used to build the artefacts. Use `script/deploy-brc.sh`: it refuses a dirty checkout or a manifest that does not match the two checked-out commits and Foundry configuration.

Ratifiers must be distinct ECDSA EOAs. Rehearse one series-domain signature from each ratifier before deployment. `code.length == 0` rejects an already deployed contract wallet, but it cannot identify an undeployed counterfactual wallet address.

## Salts and address order

Use the operational borrower account as the first 20 bytes of both `vault.salt` and `market.marketSalt`; the remaining 12 bytes are independent series nonces. The two factories reject a salt prefix belonging to somebody else.

The command calculates addresses in this order:

1. Ask `HooksFactory.computeMarketAddress(marketSalt)` for the market address.
2. Encode the complete manifest and hash it.
3. Build the reviewed `BRCNoteVault` creation bytecode with that hash and market address, then calculate the vault through the borrower-scoped CREATE2 factory and `vault.salt`.
4. Read and pin the principal's hook deployment nonce. The hook's CREATE2 salt is the 20-byte principal followed by that 12-byte nonce.
5. Build the hook constructor input with the calculated vault as the lender, then calculate the hook address from the stored template initcode.
6. Calculate the provider address from the hook address, vault lender and provider salt.
7. Have the registered borrower account check the principal and hook nonce, deploy the vault, call `deployMarketAndHooks`, and check all three returned addresses in one transaction. The vault's first child deployment is the fixing oracle.

Nothing is filled in later. In particular, the vault has no market setter.

The requested hook config enables deposit and transfer dispatch. The fixed-term template separately
forces queue-withdrawal hook dispatch on, while the market policy field
`withdrawalRequiresAccess` remains false. The fixed-term data is exactly 160 bytes:

```solidity
abi.encode(uint32(maturity), uint128(0), true, false, false)
```

The singleton constructor contains one new zero-TTL provider, no existing provider, and the vault lender in both the outer input and provider-factory calldata.

## Dry run

Use a wallet integration supported by Foundry. Keep the private key out of the manifest, shell history and deployment record. The wrapper rejects raw private-key and mnemonic arguments, along with options that could swap the project root, remappings, libraries or compiler settings after preflight.

```bash
./script/deploy-brc.sh \
  config/series.json \
  deployments/series.json \
  --rpc-url "$MAINNET_RPC_URL" \
  --sender 0xBORROWER_PRINCIPAL
```

The wrapper first checks the actual repository revisions and Foundry settings against the manifest. The Solidity dry run then prints the environment, chain ID, revisions, compiler, manifest hash, approved code hashes and every calculated address. Give that output and the filled manifest to the borrower and reviewer before adding `--broadcast`.

If the template charges an origination fee, the command approves exactly that amount immediately before `deployMarketAndHooks` and clears the approval afterwards. It never grants an unlimited approval.

## Broadcast and verify

Run the same command with the wallet's signing option and `--broadcast`. The borrower account must already be registered with the manifest's principal in Wildcat, and the account factory must have been approved by the identity registry administrator.

Run this read-only check before subscriptions open and again after deployment-state changes that
could affect the recorded assumptions:

```bash
forge script script/VerifyBRC.s.sol:VerifyBRC \
  --rpc-url "$MAINNET_RPC_URL" \
  --sig "run(string,string)" \
  config/series.json deployments/series.json
```

The verifier checks:

- the readable and encoded manifests, stored manifest hash and calculated addresses;
- current code hashes for the vault, market, hook, provider and oracle;
- the borrower account and identity registry code hashes and current principal resolution;
- every vault immutable used for funding and activation;
- market asset, borrower identities, cap, rate, reserve, delinquency, withdrawal and fee settings;
- hook template, administrator, dispatch flags and complete fixed-term policy;
- the sealed one-provider set, zero TTL and vault lender; and
- feed code and metadata, initial fixing, maturity, barrier and fallback configuration; and
- the ArchController owner and current SphereX admin, pending admin, operator and engine, plus the engine copied into the factory and market.

Any mismatch reverts with `InvalidManifest("field")` or `DeploymentMismatch("field")`, which makes the command exit non-zero and identifies the first failed field.

## Tests

`BRCDeploymentTest` deploys the pinned factory, template, provider factory, market, vault and oracle from empty local state. It restores the predeployment snapshot and proves that the same state and inputs reproduce all five addresses. It also mutates every manifest field and deployment-record field checked by the verifier.

The live-feed fork exercise is opt-in:

```bash
MAINNET_RPC_URL="$MAINNET_RPC_URL" \
  forge test --match-contract BRCDeploymentMainnetForkTest
```

It checks the current Ethereum mainnet BTC/USD proxy, then deploys and registers the pinned factory and singleton fixed-term template artefacts on the fork. No RPC URL or credential is written to the manifest, record or command output.
