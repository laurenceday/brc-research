# BRC research

Research and implementation planning for a BTC-linked barrier reverse convertible built on a fixed-term Wildcat market.

The shape is deliberately boring at the Wildcat layer. One vault is the market's sole lender. The market handles ordinary debt and interest; the vault handles note issuance, the Chainlink observation and the settlement waterfall.

This repository begins as a stack of draft task PRs. Each branch adds one bounded brief and is meant to receive its implementation before it is marked ready for review.

## Reference state

The market design assumes the singleton fixed-term hook introduced in [`wildcat-finance/v2-protocol#124`](https://github.com/wildcat-finance/v2-protocol/pull/124). At the time this research was written, that PR was open and its head was `99bb85840a77a56fa5f64504a60ec126b6047cf5`. Rebase and audit the final upstream state before using it with funds.

The example uses the standard Ethereum mainnet Chainlink BTC/USD proxy listed at [`data.chain.link`](https://data.chain.link/feeds/ethereum/mainnet/btc-usd). Deployment tooling must verify the live proxy address and feed metadata rather than trusting this document.

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

The stack is linear on purpose. Review and merge it from the bottom.
