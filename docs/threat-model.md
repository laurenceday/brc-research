# BRC vault failure analysis

## Assets and claims

The protected assets are subscribed USDC, the vault's Wildcat position, recovered USDC and the right of each note token to its share of the settled or recovered pool.

The borrower rebate is a conditional claim. It exists only after full Wildcat performance and a valid breached-barrier fixing.

## Actors

- Investors may subscribe, transfer notes where permitted and redeem.
- The borrower deploys and operates the Wildcat market.
- Any account may submit valid oracle evidence and advance permissionless settlement calls.
- Fallback ratifiers act only after the primary observation path has failed for the agreed period.
- Chainlink proxy and aggregator administrators may change the underlying feed phase.

## Failure cases

### A caller chooses the price

Reading `latestRoundData()` whenever settlement happens gives the caller a timing choice. Maturity fixing therefore accepts a round determined by `updatedAt`, with predecessor evidence and proxy-phase handling.

### The feed is stale, missing or replaced

Invalid answers pause settlement. A delayed fallback may propose a value, but it cannot become effective until the challenge period ends.

### The borrower closes or reprices early

`SingletonFixedTermHooks` rejects pre-maturity closure, term reduction and APR or reserve-ratio changes. Deployment verification checks the stored policy before the vault deposits.

### Another lender enters

The hook has one immutable pull provider bound to the vault. Deposit and transfer dispatch are required and the provider configuration is sealed. Market-token transfers are disabled for the series.

### The vault changes after launch

The vault is non-upgradeable and has no general call path. Its market, asset, feed and terms are constructor-bound.

### The borrower defaults and still receives the slash

The rebate is unavailable in recovery. Partial Wildcat proceeds remain reserved for noteholders until the market fully performs or the recovery process reaches its terminal state.

### Rounding moves value between parties

The payoff library fixes every rounding direction. Conservation properties check that the noteholder pool and borrower rebate account for the collected assets without exceeding them.

### The vault is sanctioned

The Wildcat sanctions path can quarantine the lender position or its withdrawal. Tests and legal terms must cover this delay; the BRC contracts cannot override the sanctions sentinel.

## Required accounting and state properties

- Assets leave only through refunds, note redemption or a valid borrower rebate.
- The borrower receives no rebate before full market performance.
- Each fixing and settlement transition happens at most once.
- Noteholder claims never exceed assets reserved for them.
- No address other than the vault can hold a direct market position.
- Provider configuration remains sealed.
- Settlement timing cannot change the accepted maturity round.
