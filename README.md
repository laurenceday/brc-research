# BRC research

This repo is for a BTC-linked barrier reverse convertible built on a fixed-term Wildcat market.

The Wildcat bit is intentionally pretty boring. One vault is the market's sole lender. The market handles normal debt and interest, while the vault deals with the notes, Chainlink observations and settlement waterfall.

The repo starts as a stack of draft PRs. Each branch has one job and gets its implementation before it is marked ready for review.

## Reference state

The market design uses the singleton fixed-term hook from [`wildcat-finance/v2-protocol#124`](https://github.com/wildcat-finance/v2-protocol/pull/124). That PR was still open when this was written, with `99bb85840a77a56fa5f64504a60ec126b6047cf5` at its head. Rebase onto the final upstream version and audit it before putting funds through any of this.

The example uses the standard Ethereum mainnet Chainlink BTC/USD proxy listed at [`data.chain.link`](https://data.chain.link/feeds/ethereum/mainnet/btc-usd). The deployment tooling still needs to check the live proxy address and feed metadata; this document is not that check.

## Stack

1. Fix the product specification.
2. Establish the Foundry project and pinned dependencies.
3. Implement payoff mathematics and series types.
4. Add the Chainlink oracle foundation.
5. Add deterministic maturity fixing.
6. Implement note funding and cancellation.
7. Bind and activate the Wildcat market.
8. Implement normal maturity settlement.
9. Add default recovery and oracle fallback.
10. Add deployment and verification tooling.
11. Produce the security and operational package.

The stack is linear. Review and merge it from the bottom.

Deployment lives in [`docs/deployment-tooling.md`](docs/deployment-tooling.md). Run it once without `--broadcast`, get the printed hashes and addresses signed off, then run the read-only verifier against the record before funding.
