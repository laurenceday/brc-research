# Study: bring the BRC prototype and its public explanation into the same state

## Problem statement

This repository contains a working research prototype for a cash-settled, BTC/USD-linked
barrier reverse convertible built around a fixed-term Wildcat market. The code is ahead of the
repository's opening explanation in at least three concrete places. The README still introduces an eleven-PR build
plan after all eleven PRs have merged, several task records describe tests and functions in the
future tense, and `tasks/08-normal-settlement.md` says normal settlement requires formal market
closure even though `BRCNoteVault.finalizeSettlement()` now checks complete lender payment through
`market.totalSupply() == 0`.

The work has two audiences.

1. Engineers, reviewers and operators need one accurate account of what the contracts do, what
   they do not do, which dependency commits they use, and which conditions move a series through
   funding, activation, settlement and recovery.
2. Business-development staff need enough structured-product history, payoff intuition, product
   vocabulary and oracle context to hold a useful first meeting with a lender or borrower without
   presenting research code as a production product.

A working result means all repository Markdown agrees with commit
`9b97787927ee2f9fab2907a9d3762862133fd5cd`; a new reader can start with the README and reach the
technical, commercial and operating material without guessing which page is current; and the BD
package answers four questions plainly:

- What does a BRC pay, and what risks does each side take?
- Why use a Wildcat market and a singleton lender vault?
- Which reference assets could be supported by onchain data today, and which would require new
  code, commercial data rights or both?
- What must be learned from a prospective lender, borrower, oracle vendor and legal adviser before
  a real series is specified?

The demonstration check is a cold reader following this route:

```text
README
  -> primer and worked payoff
  -> lender or borrower brief
  -> oracle/reference-asset catalogue
  -> architecture and product terms
  -> deployment runbook and review packet
```

The code gate for the starting commit is `FOUNDRY_PROFILE=ci forge test --summary`. On 16 August
2026 it compiled with Solidity 0.8.28 and reported 229 passing tests, no failures and one skipped
opt-in mainnet-fork test. The run hydrated the pinned git submodules and created an untracked
`foundry.lock`; that generated file is not part of the reviewed starting commit.

## What exists now

### Product and lifecycle

`BRCNoteVault.sol` is both the note ledger and the only direct Wildcat lender. Eligible investors
subscribe with the settlement asset and receive note units at one unit per settlement-asset base
unit. A configured series requires a full raise. The vault records its initial BTC/USD fixing in
its constructor, verifies the precommitted Wildcat market and hook policy at activation, deposits
the notional, and holds the complete scaled market position.

At maturity, any caller can queue that complete position without waiting for the BTC fixing. A
fully paid claim plus a stored maturity fixing permits normal settlement. The vault calculates a
cash rebate for the borrower and reserves the rest of the Wildcat proceeds for noteholders. If the
claim remains partly unpaid after the grace period, recovery may begin. Recovery never pays a
borrower rebate; after the fixed write-off time and the expiry of every recorded batch, all
collected Wildcat proceeds form the noteholder reserve.

The state enum is:

```text
Funding, Funded, Active, Withdrawing, Settled, Recovery, Redeemable, Cancelled
```

The meaningful paths are:

```text
Funding -> Funded -> Active -> Withdrawing -> Redeemable -> Settled
   |          |                         |
   |          +------> Cancelled        +-> Recovery -> Redeemable
   +-----------------> Cancelled
```

`Settled` follows the payment of both liabilities: all notes are burned and any nonzero borrower
rebate is claimed. `Redeemable` is therefore the payout state, not the terminal state.

### Payoff

The prototype implements a European maturity barrier with strike `K = S0` and barrier
`B = floor(S0 * barrierBips / 10,000)`. Equality with the barrier counts as a breach.

For notional `N` and maturity fixing `ST`:

```text
slash = 0                                           when ST > B
slash = floor(N * (K - ST) / K)                    when ST <= B and ST < K
slash = 0                                           otherwise

borrower rebate = slash                             on complete Wildcat performance
noteholder pool  = collected Wildcat proceeds - slash
borrower rebate = 0                                 in recovery
noteholder pool  = recovered Wildcat proceeds       in recovery
```

Accrued Wildcat interest always remains in the noteholder pool. The slash is calculated against
face principal rather than principal plus interest. The lender has no participation in BTC upside.
This makes the note economically similar to unsecured borrower credit plus a put written by the
lender on BTC/USD, subject to the exact barrier convention and the separate Wildcat default path.

### Oracle

`BtcUsdFixingOracle.sol` supports one concrete source shape: a Chainlink AggregatorV3 BTC/USD proxy
whose phase aggregators can be inspected through `phaseAggregators(uint16)`. It pins feed decimals
and the hash of `description()`. It records a fresh positive initial round before maturity and a
deterministic first valid round at or after maturity within the observation window. The maturity
proof handles proxy phase changes and bounds the number of rounds scanned.

The delayed fallback is a distinct path. One of one to eight immutable ECDSA ratifiers opens a
proposal after the waiting time; distinct ratifier signatures build the immutable threshold; any
ratifier may veto; a valid primary proof cancels an active fallback; and a final fallback cannot be
overwritten. The signature domain commits to chain, oracle, series, proposal nonce, price,
observation time, source and evidence hash.

This source shape excludes Chainlink Data Streams, Pyth, RedStone pull reports, API3 dAPIs and UMA
without a new adapter and a new evidence rule. The research package must not describe them as
configuration choices available to this deployment.

### Wildcat and deployment

The vault checks a singleton fixed-term hook deployment from
`wildcat-finance/v2-protocol` commit `99bb85840a77a56fa5f64504a60ec126b6047cf5`, the head of open
PR 124 as checked on 16 August 2026. It verifies the market address, settlement asset, operational
borrower, registered borrower principal, cap, APR, reserve ratio, delinquency terms, fee recipient,
protocol fee, hook template, complete fixed-term policy, sealed provider configuration, zero TTL,
singleton lender, transfer policy and provider-factory runtime before depositing.

`BRCBorrowerAccount.deploySeries()` makes vault creation, the principal-wide hook nonce check,
governance and fee checks, hook/market deployment, address checks and fee-allowance cleanup one
principal-authorised transaction. `BRCDeployment.sol`, `DeployBRC.s.sol`, `VerifyBRC.s.sol` and the
shell wrappers turn the JSON manifest into deterministic addresses and verify the result against
chain state.

The prototype is immutable at the vault level. It has no general executor, upgrade function,
delegatecall route or asset sweep. It still depends on live external powers: Wildcat governance,
SphereX, the borrower identity registry, Chainlink feed operation, sanctions controls and the
settlement token.

### Current documentation

The current pages fall into four groups:

| Group | Files | Present condition |
| --- | --- | --- |
| Entry point | `README.md` | Accurate architecture sketch, stale build-stack framing and incomplete navigation |
| Current technical truth | `docs/architecture.md`, `docs/product-terms.md`, `docs/threat-model.md` | Mostly aligned with code; needs cross-links, status labels and a shared vocabulary |
| Operations and review | `docs/deployment-tooling.md`, `docs/runbook.md`, `docs/operations-checklists.md`, `docs/review-packet.md`, `docs/validation-evidence.md` | Detailed and useful; needs a current evidence refresh and a cold read for internal contradictions |
| Historical build record | `tasks/01-product-spec.md` through `tasks/11-security-validation.md` | Written as proposed work; should identify itself as the record of the merged stack and distinguish plan from shipped result |

The new commercial and research pages should sit beside the technical docs, not replace them.

## Prior art

### Structured-product lineage

A reverse convertible combines issuer debt with a put option sold by the investor. The coupon is
higher than comparable plain debt because it includes compensation for the option and may include
other issuer economics. If the reference asset satisfies the adverse redemption condition, the
investor receives depreciated shares, or their cash equivalent, rather than full cash principal.
The investor retains issuer credit risk and gives up reference-asset upside.

The term covers several observation conventions. An American or continuously observed knock-in
can be triggered during the note's life. A European barrier is observed only at maturity. Some
products test the final level without a separate barrier. Worst-of notes reference the weakest
member of a basket. Callable and autocall structures add early-redemption rights. Those features
have different option values and conduct risks and must not be grouped as cosmetic variants.

Swiss guidance calls reverse convertibles “products with cash or security delivery” and describes
the bond-plus-written-put decomposition. Circular No. 15 also distinguishes the ordinary bond
interest from option-premium economics for tax analysis. Tax treatment depends on the investor,
issuer, product transparency, jurisdiction and date. No repository page should promise that a
tokenised version receives the historical Swiss treatment.

The GOAL label is commonly expanded as “Geld Oder Aktien Lieferung” (cash or delivery of shares).
The supplied transcript attributed an early-1990s launch to Vontobel. That date and attribution
have not been substantiated in primary material. A contemporary Euromoney account instead reports
that Warburg Dillon Read created the GOAL brand around the 1998 football World Cup, while an
official UBS product brochure uses the GOAL name and explains the bond-plus-put structure. The
research report must record the conflict rather than repeat the transcript's claim.

Comparable families include German `Aktienanleihen`, US reverse exchangeables and branded equity-
linked notes, UK precipice/high-income bonds, Japanese equity- or Nikkei-linked bonds, discount
certificates, autocalls and contingent-income notes. Their shared economic parts do not imply the
same tax, disclosure, settlement or regulatory treatment.

FINRA describes reverse convertibles as complex, short-dated high-yield notes with issuer credit,
reference-asset downside, liquidity and feature risk. SEC-filed issuer material continues to show
the product in 2026: an unsecured note, a fixed coupon, a final barrier and equity or cash-equivalent
delivery below the barrier. Those documents are useful prior art for balanced lender disclosure,
not a legal template for this prototype.

### Onchain reference data

Chainlink's public catalogue lists data categories including crypto, fiat, commodities, equities,
ETFs, indices, fixed income, macroeconomics, NAV, money-market and tokenised-fund data. Product
names alone do not establish that a feed is available on Ethereum mainnet, that historical rounds
can be proven through the AggregatorV3 proxy interface, or that its licence permits settlement of a
financial instrument. Each proposed series needs an address-level, chain-level and rights-level
check.

Chainlink products have distinct delivery models:

| Product | Typical data/delivery | Relevance here |
| --- | --- | --- |
| Data Feeds | Push-based onchain AggregatorV3 values, normally deviation/heartbeat updated | The only implemented primary path, and only for the pinned BTC/USD proxy shape |
| Data Streams | Pull-based signed reports with lower-latency fields | Candidate for future adapters; not readable by `BtcUsdFixingOracle` |
| SmartData | NAV, AUM, reserve or other token-specific data | Candidate for fund/NAV-linked terms; may be valuation data rather than a tradable close |
| Proof of Reserve | Reserve or collateral attestations | Useful as a covenant or condition; not automatically a price |
| Custom feeds / CRE workflows | Contract-specific offchain data and processing | Possible route for licensed benchmark or fixing data after commercial and technical review |

Pyth documents real-time crypto, US equity, FX, metal, rates, commodity-futures, energy and crypto-
index classes. Its material also publishes market sessions and carries stale/carry-forward semantics
outside some market hours. Pyth Core and Pyth Pro use different feed identifiers and access models.
RedStone advertises more than 1,300 feeds across crypto, LST/LRT, RWA and tokenised-fund classes,
with push and pull models. API3 exposes first-party dAPIs with heartbeat/deviation update parameters.
UMA can settle an arbitrary documented assertion through a bonded optimistic proposal and dispute
process, with a DVM vote as backstop. None is a drop-in replacement for the current proxy-round proof.

Reference-asset candidates divide naturally:

| Candidate | Data case | Product question | Main difficulty |
| --- | --- | --- | --- |
| BTC, ETH and liquid crypto | Strongest 24/7 onchain coverage | Single asset, basket, ratio or volatility-linked? | Venue composition, fork events and stablecoin quote risk |
| Major FX | Broad weekday coverage | Which fixing time, base/quote convention and holiday calendar? | Weekend closure, benchmark rules and settlement currency mismatch |
| Gold and other metals | Spot and futures sources exist | Spot, front future or rolling index? | Maintenance windows, roll policy and data rights |
| Oil, gas and agriculture | Futures coverage is more natural than spot | Which contract month and roll rule? | Expiry, negative prices, thin contracts and delivery geography |
| US equities and ETFs | Pull products and some onchain feeds exist | Official close, extended-hours print or 24/7 token price? | Market hours, corporate actions, venue differences and licensing |
| Equity indices | Commercial sources and selected onchain markets exist | Price return, total return, future or ETF proxy? | Index-product licence, close definition and source rights |
| Rates and Treasuries | Reference rates, futures and tokenised-fund NAVs exist | Rate level, price, yield, spread or total return? | Units, publication calendars, revisions and convexity |
| Tokenised funds/private credit | NAV and reserve data may exist | Price, NAV, redemption rate or impairment event? | Slow valuations, administrator discretion and correction policy |
| Custom crypto/TradFi baskets | Calculable from several inputs | Worst-of, equal weight or governed rebalance? | Correlation, synchronized observations, constituent changes and gas |

S&P Dow Jones Indices states that financial institutions license its indices for structured
products and that product use requires a licence. Referencing an S&P 500 value therefore needs a
commercial rights review separate from the oracle integration. An ETF proxy such as SPY changes
the economic exposure and does not by itself answer trademark, market-data or product-licensing
questions.

## Constraints and non-goals

### Fixed starting point

- Repository: `laurenceday/brc-research`
- Base branch and commit: `main` at `9b97787927ee2f9fab2907a9d3762862133fd5cd`
- Solidity: 0.8.28, Cancun EVM, optimizer 200 runs, via IR, no bytecode metadata hash
- Foundry: 1.7.1 at `4072e48705af9d93e3c0f6e29e93b5e9a40caed8`
- Wildcat v2-protocol: `99bb85840a77a56fa5f64504a60ec126b6047cf5`
- forge-std: `467ffd422ca01fed5797a4c766a1e4e3a5327902`
- Chainlink AggregatorV3 source pin:
  `f82d1ac09fc5d3190600d308be99a4a509854686`
- Example primary feed: Ethereum mainnet BTC/USD proxy
  `0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c`

### This run will do

- Reconcile every existing Markdown page with implemented behaviour.
- Preserve the eleven task pages as an intelligible implementation record while changing stale
  proposals and false present-tense claims.
- Add a sourced history and market report, a plain-language primer, lender and borrower briefs, a
  meeting/discovery guide, an oracle and reference-asset catalogue, and reusable infographics.
- Label every source or asset as implemented, verified candidate, vendor-discussion candidate or
  legally/commercially unresolved.
- Refresh validation evidence after the final tree is frozen.
- Run the Fiat audit and prose phases for every stacked step.

### This run will not do

- Change payoff, oracle, vault, Wildcat or deployment code merely to make a broader sales story
  true.
- Claim production readiness, an external audit, legal approval, tax treatment, index rights,
  product suitability or a live deployment.
- Design retail distribution. The working audience is professional and institutional; jurisdiction,
  offering and suitability decisions remain with counsel and regulated distributors.
- Treat a data vendor's catalogue entry as permission to issue a linked financial product.
- Add a generic multi-oracle abstraction without a separate product and security specification.
- Invent lender demand, borrower appetite, expected volume, coupon levels or pricing economics.
- Replace the existing BTC/USD example with an S&P 500 series. The research should explain the
  work required to do that honestly.

The phrase “every single Markdown” is read literally: tracked `*.md` files present in the final
stack, including the new research and BD pages and all eleven task records, receive the final prose
pass. Vendored submodule Markdown is outside the repository's authored scope.

## Design options

### Option A: one long report

Put history, primer, product mechanics, oracle catalogue, commercial scripts and diagrams into one
large document.

This is simple to publish but poor in use. A borrower should not need to search through tax history
to find the payoff; an engineer should not need to separate a sales prompt from a
`BRCNoteVault` accounting invariant; and a
single page will become stale in several unrelated ways.

### Option B: audience-led document set with one factual spine

Keep architecture, terms, `docs/threat-model.md` and operations as the technical spine. Add separate research,
primer, lender, borrower, discovery and oracle/reference-asset pages. Put reusable diagrams in one
infographic page and link them from the audience documents. Make the README a map with explicit
status labels.

This is the selected construction. It costs more links but each page has one reader and one job.
Facts that can change, such as feed availability and PR state, get an “as of” date and source.
Implemented behaviour stays in the technical spine; commercial hypotheses stay in the BD pages.

### Option C: generated static microsite or slide deck

Build a site or presentation from a shared content model.

That may become useful once product positioning and design language have survived live meetings.
It is premature here: it adds build tooling and presentation choices before the facts and questions
have settled. Markdown plus source-controlled diagrams is easier to review, quote and maintain.

### Option D: code-led API reference only

Generate interfaces and state-machine documentation directly from Solidity.

This would reduce mechanical drift but cannot explain instrument history, buyer motives, data
rights or meeting questions. Generated reference can be added later; it is not a substitute for the
requested package.

## Proposed information architecture

```text
README.md                              status, warning, map and fastest routes
docs/primer.md                         mechanics, worked examples and terminology
docs/research/instrument-history.md    sourced BRC and comparable-instrument history
docs/research/oracle-landscape.md      onchain sources and reference-asset catalogue
docs/bd/lender-brief.md                lender proposition, risks and qualification questions
docs/bd/borrower-brief.md              borrower use cases, costs, risks and qualification questions
docs/bd/discovery-guide.md             first-call script, question bank and follow-up evidence
docs/bd/infographics.md                reusable payoff, lifecycle, risk and data-selection diagrams
docs/architecture.md                   current implementation
docs/product-terms.md                  example BTC series terms
docs/threat-model.md                   failure analysis
docs/deployment-tooling.md             deterministic deployment and verification
docs/runbook.md                        deployment-through-settlement sequence
docs/operations-checklists.md          role-owned operating controls
docs/review-packet.md                  security/legal handoff
docs/validation-evidence.md            commands run and evidence not obtained
tasks/01...11.md                       merged implementation record, current result and boundaries
```

Each commercial page opens with the same status statement: research prototype; professional
discussion only; no offer, recommendation, forecast, tax conclusion or claim of production safety.
That statement cannot replace legal review, but it prevents the documents from contradicting the
review packet while research is underway.

## Risk register seed

| Area | What the audit and cold read must test | Why it matters |
| --- | --- | --- |
| Payoff language | Barrier equality, maturity-only observation, strike at `S0`, face-principal slash, interest ownership | Small wording changes describe a different option |
| Credit and market interaction | Full payment, partial recovery, valid fixing during default, late payment after write-off | The lender is exposed to both borrower credit and BTC downside |
| Oracle determinism | First valid maturity round, proxy phase changes, scan bound, staleness and future skew | A caller must not choose a favourable round |
| Alternative-source claims | Interface, chain, report format, historical proof and correction semantics | Vendor catalogue coverage is not implemented support |
| Data and index rights | Product licence, display rights, derived data, trademark and official close | A technically available number may not be commercially usable |
| Market sessions | Weekends, holidays, halts, maintenance windows, extended hours and carry-forward prices | “Price at maturity” is incomplete for TradFi assets |
| Corporate actions | Splits, dividends, mergers, spin-offs, delistings and constituent changes | A raw price can change without an economic loss |
| Futures | Contract identity, roll, expiry, negative prices and delivery location | “Oil price” is not one instrument |
| Fallback authority | EOA custody, threshold, unilateral veto, source definition and evidence publication | The fallback is a governed price path after the primary fails |
| Recovery liveness | Queue horizon, SphereX, sanctions escrow, batch expiry and late proceeds | Missing the queue window leaves no onchain recovery transition |
| Deployment authority | Principal identity, hook nonce, governance fields, deterministic salts and fee allowance | A valid-looking deployment can bind the wrong external state |
| Note transfers | Eligibility controller, allowance semantics, loss of eligibility and secondary transfer claims | “Transferable” has technical and distribution meanings |
| BD suitability claims | Target client, loss capacity, liquidity, valuation and hedging sophistication | High coupon language can conceal principal and issuer risk |
| Historical claims | GOAL origin, popularity, tax effect and national analogues | The transcript includes at least one unsupported attribution |
| Evidence freshness | Test counts, fork block, PR state, feed address and current source catalogue | These facts change independently of prose quality |

## Glossary seeds

- **AggregatorV3:** Chainlink's push-feed interface used by the implemented primary oracle.
- **Barrier:** The adverse reference level whose satisfaction activates the maturity loss formula;
  equality counts as breach in this prototype.
- **BRC:** Barrier reverse convertible, a reverse convertible with a separate knock-in condition.
- **Borrower rebate:** The portion of completely collected Wildcat proceeds returned to the borrower
  after a barrier breach; never available in recovery.
- **Coupon:** The Wildcat lender yield. Its legal and tax character is not determined by the code.
- **European barrier:** A barrier observed at the maturity fixing only.
- **Fallback fixing:** A delayed maturity price accepted through the immutable ratifier process when
  the primary Chainlink proof is unavailable.
- **Fixing:** The single price selected under a documented observation rule.
- **GOAL:** A brand/label expanded as “Geld Oder Aktien Lieferung”; its exact commercial origin must
  be cited carefully.
- **Knock-in:** The event that activates the downside redemption formula.
- **Noteholder reserve:** Settlement assets attributed to outstanding note redemption.
- **Primary fixing:** The initial or maturity price proven from the pinned Chainlink proxy and round
  rules.
- **Recovery:** The path for a completely queued Wildcat claim that remains partly unpaid after the
  contractual grace period.
- **Reference asset:** The asset, rate, index or value whose fixing controls the contingent payoff.
- **Reverse convertible:** Issuer debt combined economically with a put sold by the investor.
- **Singleton lender:** The vault is the only address admitted to hold the direct Wildcat lender
  position.
- **`S0`:** The initial fixing and strike in the example series.
- **`ST`:** The accepted maturity fixing.
- **Write-off time:** The earliest time when a recovery pool can be finalised from collected batches.

## Sources

### Repository and dependency sources

- `src/BRCNoteVault.sol`, `src/BtcUsdFixingOracle.sol`, `src/BRCMath.sol`,
  `src/BRCBorrowerAccount.sol`, `src/BRCDeployment.sol` and `script/*.sol` at
  `9b97787927ee2f9fab2907a9d3762862133fd5cd`
- `config/dependencies.env`, `config/series.example.json` and `foundry.toml`
- Wildcat v2-protocol PR 124 and pinned commit:
  <https://github.com/wildcat-finance/v2-protocol/pull/124>
- Chainlink BTC/USD Ethereum feed page:
  <https://data.chain.link/feeds/ethereum/mainnet/btc-usd>

### Instrument and conduct sources

- Swiss Federal Tax Administration, Circular No. 15, “Bonds and derivative financial instruments,”
  section 2.3.3 on reverse convertibles:
  <https://www.estv.admin.ch/dam/de/sd-web/2H5NhZhB6Evl/dbst-ks-2007-1-015-dvs-de.pdf>
- FINRA, “Reverse Convertibles: Complex Investments,” 7 July 2023:
  <https://www.finra.org/investors/insights/reverse-convertibles-complex-investments>
- FINRA Regulatory Notice 12-25 and cited reverse-convertible cases:
  <https://www.finra.org/rules-guidance/notices/12-25>
- Citigroup, “Reverse Convertibles: A Guide for Investors,” SEC filing dated 5 March 2026:
  <https://www.sec.gov/Archives/edgar/data/0000200245/000095010326003335/dp242866_424b2-elksbroch.htm>
- Morgan Stanley RevCons product filing, 2008:
  <https://www.sec.gov/Archives/edgar/data/895421/000095010308003008/dp12070_424b2-revcons.htm>
- UBS GOAL Kick-In brochure:
  <https://keyinvest-ch.ubs.com/filedb/deliver/xuuid/l001fba3c79c5c074ffcbdaaa88b1be8cc4b/name/GOAL_Kick-In_GOAL_DE.pdf>
- Euromoney, “Equity derivatives: Riding the tiger of volatility,” contemporary account of the
  GOAL brand:
  <https://www.euromoney.com/article/27bjsstsqxhkmh14o5nz9/equity-derivatives-riding-the-tiger-of-volatility/>

### Oracle and data sources

- Chainlink Data Feeds overview and live catalogue:
  <https://chain.link/data-feeds> and <https://data.chain.link/feeds>
- Chainlink data for tokenised assets:
  <https://chain.link/article/data-for-tokenized-assets>
- Chainlink Data Streams documentation and release notes:
  <https://docs.chain.link/data-streams> and
  <https://docs.chain.link/data-streams/release-notes>
- Pyth asset classes, feed IDs and market hours:
  <https://docs.pyth.network/price-feeds/core/price-feeds/asset-classes>,
  <https://docs.pyth.network/price-feeds/core/price-feeds/price-feed-ids> and
  <https://docs.pyth.network/price-feeds/pro/market-hours>
- RedStone feed catalogue:
  <https://www.redstone.finance/price-feeds>
- API3 integration and data-feed model:
  <https://docs.api3.org/dapps/integration/index.html> and
  <https://docs.api3.org/oev/in-depth/data-feeds/>
- UMA Optimistic Oracle overview:
  <https://docs.uma.xyz/protocol-overview/how-does-umas-oracle-work>
- S&P Dow Jones Indices data and index licensing:
  <https://www.spglobal.com/spdji/en/about-us/data-index-licensing/>
- S&P Global terms governing index use in financial products:
  <https://www.spglobal.com/en/terms-of-use>

All market coverage and repository-state claims in the shipped research report need an “as of
16 August 2026” label. An operator must recheck addresses, source terms and product licences for
each series rather than relying on this study.
