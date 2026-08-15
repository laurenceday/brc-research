# BRC vault failure analysis

## Assets and claims

The things we're protecting are subscribed USDC, the vault's Wildcat position, recovered USDC and each note token's right to its share of the settled or recovered pool.

The borrower rebate is conditional. It only exists after full Wildcat performance and a valid breached-barrier fixing.

## Actors

- Investors may subscribe, transfer notes where permitted and redeem.
- The borrower deploys and operates the Wildcat market.
- Any account may submit valid oracle evidence and advance permissionless settlement calls.
- Fallback ratifiers act only after the primary observation path has failed for the agreed period.
- Chainlink proxy and aggregator administrators may change the underlying feed phase.
- The Wildcat ArchController's SphereX admin and operator may replace the engine and propagate it to the market.
- The Wildcat ArchController owner may change a hook template's protocol fee and push it to the active market.

## Failure cases

### A caller chooses the price

Reading `latestRoundData()` whenever somebody settles gives that caller a timing choice. Maturity fixing instead takes the round determined by `updatedAt`, with predecessor evidence and proxy-phase handling.

### The feed is stale, missing or replaced

Invalid answers pause settlement. The delayed fallback can propose a value, but that value does nothing until the challenge period ends.

### The borrower closes or reprices early

`SingletonFixedTermHooks` rejects early closure, term reduction and APR or reserve-ratio changes. The deployment check reads the stored policy before the vault deposits.

### Another lender enters

The hook has one immutable pull provider bound to the vault. Deposit and transfer dispatch are required, the provider configuration is sealed, and market-token transfers are disabled for the series.

### The vault changes after launch

The vault is non-upgradeable and has no general call path. Its market, asset, feed and terms are all fixed in the constructor.

### The borrower defaults and still receives the slash

There is no rebate in recovery. Partial Wildcat proceeds stay reserved for noteholders until the market fully performs or recovery reaches its terminal state.

### Rounding moves value between parties

The payoff library spells out every rounding direction. Its accounting checks make sure the noteholder pool and borrower rebate cover the collected assets without exceeding them.

### The vault is sanctioned

Wildcat's sanctions path can quarantine the lender position or its withdrawal. It can also queue the complete position before the vault starts settlement. The vault can adopt that authenticated batch and continue once the assets reach it, but it cannot override or pull assets out of the sanctions escrow.

### The withdrawal expiry wraps

Wildcat stores withdrawal expiries in 32 bits. The vault refuses terms that would run off the end after allowing for the observation window, withdrawal delay and the extra second Wildcat may need on close. It checks again at queue time because a keeper can still be late. Miss that window and the position stays `Active` for recovery; the vault never asks Wildcat to write a wrapped expiry.

### SphereX blocks a withdrawal

The Wildcat ArchController's SphereX admin and operator can replace the engine used by a registered market. That engine runs around withdrawal queueing and execution, and can make either call revert. The manifest records the ArchController, admin, operator and engine seen before funding; the vault does not freeze them. A hostile or broken engine can delay the sole lender's withdrawal, and the vault has no local bypass after activation. Watch it for the whole term.

### Protocol fees dilute recovery

The vault checks the fee recipient and protocol fee before activation. After that, the ArchController owner can change the template fee and push it to the market, up to 1,000 bips. Protocol fees add to borrower debt when everything pays out. In default, accrued fees sit ahead of an unpaid lender withdrawal and the recipient can collect them, leaving less for noteholders. The manifest records the starting values, owner, ceiling and mutability. None of that pretends the fee is frozen.

## Required accounting and state properties

- Assets leave only through refunds, note redemption or a valid borrower rebate.
- The borrower receives no rebate before full market performance.
- Each fixing and settlement transition happens at most once.
- Noteholder claims never exceed assets reserved for them.
- No address other than the vault can hold a direct market position.
- Provider configuration remains sealed.
- Settlement timing cannot change the accepted maturity round.
