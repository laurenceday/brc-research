# BRC vault failure analysis

## Assets and claims

The things being protected are subscribed settlement assets, the vault's Wildcat position,
recovered settlement assets and each note balance's right to its share of the settled or recovered
pool. The example series uses USDC.

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

Invalid answers pause the primary route. After the observation deadline and fallback wait, any immutable ratifier may propose a value from the source fixed in the series terms. The value does nothing until the challenge period ends and the immutable threshold has signed. Restricting proposal creation stops an outsider squatting on the sole pending slot. Any ratifier can veto it, and a valid primary proof cancels it while it is pending.

The contract cannot prove that no valid Chainlink round exists but has merely gone unsubmitted. Ratifiers must check that before signing. Once the fallback is final, a later primary proof does not replace it.

The fallback verifier uses `ecrecover`, so every immutable ratifier must be an ECDSA EOA. Deployment rejects addresses that already contain code. The launch rehearsal must also collect and verify one series-domain signature from every ratifier; a counterfactual contract-wallet address can otherwise look empty at deployment but never approve a proposal.

### The borrower closes or reprices early

`SingletonFixedTermHooks` rejects early closure, term reduction and APR or reserve-ratio changes. The deployment check reads the stored policy before the vault deposits.

### Another lender enters

The hook has one immutable pull provider bound to the vault. Deposit and transfer dispatch are required, the provider configuration is sealed, and market-token transfers are disabled for the series.

### The vault changes after launch

The vault is non-upgradeable and has no general call path. Its market, asset, feed and terms are all fixed in the constructor.

### The borrower defaults and still receives the slash

There is no rebate in recovery, even if a valid breached-barrier price already exists. The vault may
queue from maturity before the BTC fixing is available, so oracle timing cannot force a funded
claim into recovery. Recovery only opens after the separate contractual `recoveryDelay` while that
queued claim remains partly unpaid; Wildcat's `delinquencyGracePeriod` is a different setting. A
fully paid claim follows normal settlement and preserves any earned rebate. Partial Wildcat
proceeds stay locked until the date fixed for write-off eligibility, then the recovered pool
belongs entirely to noteholders.

### Somebody writes off recoverable value

Recovery finalisation is permissionless after the fixed eligibility time. Before it can happen, the vault must account for the complete scaled position and every recorded batch must have expired. Finalisation collects every amount Wildcat has made withdrawable, then takes the terminal snapshot; it does not require Wildcat to pay the rest. A caller cannot race an executable withdrawal with a zero-value write-off. Later market payments and stray token transfers do not increase note claims.

### A fallback signature is replayed

Each signature binds the chain ID, oracle address, series identifier, proposal nonce, price, observation time, evidence hash and source. Approvals are one per immutable ratifier and per nonce. A vetoed proposal cannot reuse approvals when its replacement gets a new nonce.

### Rounding moves value between parties

The payoff library spells out every rounding direction. Its accounting checks make sure the noteholder pool and borrower rebate cover the collected assets without exceeding them.

### The vault is sanctioned

Wildcat's sanctions path can quarantine the lender position or its withdrawal. It can also queue the complete position before the vault starts settlement. The vault can adopt that authenticated batch and continue once the assets reach it, but it cannot override or pull assets out of the sanctions escrow.

### The withdrawal expiry wraps

Wildcat stores withdrawal expiries in 32 bits. The vault refuses terms that would run off the end after allowing for the observation window, withdrawal delay and the extra second Wildcat may need on close. It checks again at queue time because a keeper can still be late. Miss that window and the position stays `Active`; neither normal settlement nor recovery can begin. The vault never asks Wildcat to write a wrapped expiry, and operators must use the external transaction and legal fallback plan.

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
- Recovery never creates a borrower rebate.
- A fallback fixing needs the deployed threshold and survives no ratifier veto.
