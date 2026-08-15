# Task 06: take subscriptions and make failed raises boring

Status: implemented and merged. This step added note balances, subscriptions, funding finalisation, cancellation and refunds.

## What shipped

During `Funding`, one settlement-asset base unit mints one note base unit. The note copies the settlement asset's decimals. Subscriptions stop at the hard cap or funding deadline.

The generic vault constructor can express a minimum below notional. The manifest-backed BRC deployment added later requires `minimumRaise == notional`, so a configured Wildcat series activates only after a full raise.

The transfer policy is fixed at deployment. Restricted subscriptions check the payer and recipient. Direct transfers check sender and recipient, while delegated transfers also check the operator. Eligibility can change, but neither cancellation refunds nor final redemption require current eligibility.

The vault checks balance changes as well as ERC-20 return data. It accepts standard `true` returns and old no-return tokens. False returns, malformed return data, transfer fees, rebases that create a deficit and short-paid refunds revert.

Outstanding notes are the funding liability. The vault must hold at least that many settlement units, but surplus is tolerated because anybody can transfer tokens directly to an ERC-20 recipient. A surplus never mints notes or enlarges a refund.

After an unsuccessful raise, holders burn their current notes and pull refunds themselves. Note transfers before cancellation change who owns that refund claim.

## Evidence

`test/BRCNoteVault.t.sol` covers partial and exact fills, cap and deadline boundaries, funding finalisation, cancellation, repeated transitions, restricted and unrestricted transfers, allowance revocation, unusual ERC-20 return behaviour, transfer fees, rebases, surplus and refunds after eligibility revocation.

`BRCFundingInvariantTest` later checks that note supply, holder balances and settlement assets continue to reconcile across mixed subscriptions, transfers, finalisation, cancellation and refunds.

## Boundary of this step

Task 06 did not verify or fund a Wildcat market, record an oracle fixing or settle the note. Task 07 added activation; tasks 08 and 09 added maturity and recovery.
