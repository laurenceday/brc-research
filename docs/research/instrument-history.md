# Reverse convertibles: history, relatives and lessons for Wildcat

Research checked 16 August 2026. This is a product-history note, not tax, legal or investment
advice. Tax outcomes depend on the instrument, holder, issuer, jurisdiction and date.

## The idea in one sentence

A reverse convertible combines issuer debt with a put sold by the investor. The debt supplies the
funding return; the put supplies extra premium and exposes principal to a fall in an unrelated
reference asset.

That description matters more than the label. Banks have sold the same economic trade under names
including reverse convertible, reverse exchangeable, GOAL, Aktienanleihe and equity-linked
security. Barriers, baskets, call rights and settlement choices then change the exact payoff.

FINRA describes the modern form as a short-term, high-yield note linked to a stock, index,
commodity or basket. Its two components are a debt instrument and a put option granted to the
issuer. The higher coupon is the price of accepting issuer credit risk, reference-asset downside
and limited or no participation in upside. [FINRA's current investor explanation](https://www.finra.org/investors/insights/reverse-convertibles-complex-investments)
and [Regulatory Notice 10-09](https://www.finra.org/sites/default/files/NoticeDocument/p120920.pdf)
set out those mechanics and the related sales-practice concerns.

## A careful chronology

### Before the GOAL name

Debt combined with conversion rights, warrants and options predates the retail reverse-convertible
market. A conventional convertible gives the investor an equity conversion right. A reverse
convertible turns the choice around: the investor has, in economic terms, sold the issuer a put on
the reference asset. It is better treated as a branch of structured notes than as the invention of
one bank on one date.

The Japanese bubble era produced many equity- and Nikkei-linked bonds. Japan's Ministry of Finance
records the rapid expansion of warrant bonds, convertible bonds and other equity finance during the
1980s, followed by the balance-sheet damage after the 1989 peak. That is sound context for
equity-linked debt, but the sources reviewed here do not establish that every Nikkei-linked bond had
the payoff of a modern barrier reverse convertible. [Japan Ministry of Finance history](https://www.mof.go.jp/english/pri/publication/policy_1972-1990/Full_edition1972-1990.pdf)

### 1998: the GOAL label

A contemporary Euromoney account says Warburg Dillon Read's equity-derivatives team coined the
GOAL name during the June 1998 football World Cup. It expands the German phrase *Geld- oder
Aktienlieferung*: delivery in cash or shares. The same report describes a high-coupon bond issued in
exchange for a put granted by investors. [Euromoney, “Riding the tiger of volatility”](https://www.euromoney.com/article/27bjsstsqxhkmh14o5nz9/equity-derivatives-riding-the-tiger-of-volatility/)

An official UBS brochure later described GOAL as a bond plus a sold put on one or more stocks or an
equity index. It also distinguished the standard, cash-settled Score, kick-in and worst-of variants.
[UBS GOAL/Kick-in GOAL brochure](https://keyinvest-ch-en.ubs.com/filedb/deliver/xuuid/l00106ab66af84cd4d9cb182dc13fb630f20/name/GOAL_Kick-In_GOAL_EN.pdf)

Those sources do not support the earlier claim that Vontobel launched GOAL in the early 1990s. This
repository therefore attributes the label to Warburg Dillon Read in 1998 unless stronger primary
evidence emerges. It does not treat that date as the birth of the underlying economic structure.

### Late 1990s and 2000s: national forms spread

Germany's *Aktienanleihe* is the closest plain-language relative: a high coupon with redemption in
cash or shares according to the reference share price. The name and tax rules differ; the investor
still bears both issuer credit and equity downside. BaFin's later review work included product
information sheets for *Aktienanleihen*, which is evidence of an established retail category rather
than proof of one universal term set. BaFin lists the 2015 report in its [official annual-report
archive](https://www.bafin.de/DE/PublikationenDaten/Jahresbericht/jahresbericht_artikel.html?cms_gts=19659172_list%253DdateOfIssue_dt%252Basc).

The UK sold “precipice” or high-income bonds between the late 1990s and early 2000s. These were not
one standard reverse-convertible contract, but they shared the conduct problem: a prominent income
rate paired with capital loss that was harder to see. The Financial Services Consumer Panel later
described high-risk products marketed to pensioners with double-digit returns while the capital
risk received inadequate prominence. It reported an estimate of £7.4 billion invested from 1997 to
2004 and recorded FSA fines and warnings. [Consumer Panel case study](https://www.fca.org.uk/panels-assets/consumer-panel/publication/fscp_response_hmt_oct10.pdf)

US issuers used labels including reverse convertible notes and equity-linked securities. A 2011
Morgan Stanley ELKS filing described an investor deposit plus an option on a forward contract,
possible cash or share settlement, no ordinary equity upside, issuer credit risk and uncertain tax
treatment. [SEC-filed ELKS terms](https://www.sec.gov/Archives/edgar/data/895421/000095010311003000/dp25408_fwp-ps898.htm)

FINRA's 2010 notice followed heavy retail sales in the run-up to the financial crisis. It stressed
that the note rating did not measure the embedded market risk, that principal was not guaranteed,
and that secondary liquidity might depend on the issuer or dealer. FINRA also recorded enforcement
over unsuitable and poorly supervised sales to elderly and modest-net-worth customers.
[FINRA disciplinary report](https://www.finra.org/sites/default/files/DisciplinaryAction/p122644.pdf)

### The barrier and autocall branches

A standard reverse convertible can test a strike at maturity. A barrier reverse convertible adds a
knock-in threshold. The threshold may be observed continuously, daily or only at maturity. A
worst-of note links the result to the weakest member of a basket. An autocall adds early redemption
when a call condition is met.

These details are not decoration. A note can have a 60% barrier but, once knocked in, calculate loss
from a 100% strike. That creates a cliff: crossing the barrier can expose the investor to the entire
fall from the strike, not merely the fall below the barrier. Continuous observation also turns data
availability during a crash into part of the payoff. The Wildcat example avoids that problem by
using one European observation at maturity, but retains the cliff.

## The Swiss tax history, stated narrowly

The Swiss Federal Tax Administration's Circular No. 15 is the best source for the tax feature that
made these products distinctive in Swiss private banking. The 2017 circular, effective for income
falling due from 1 January 2018, describes reverse convertibles as combinations of a bond and an
option. It says the investor buys the bond and sells the put; the issuer's payments can comprise
market-rate bond interest and put premium.

For reverse convertibles that qualify as transparent products, the circular says the investment
and option transactions are separated for tax purposes. Market-conforming interest on the bond
component is relevant to income and, where applicable, withholding tax. The issuer-paid option
premium is excluded from taxation under the circular's derivative treatment. Products with
predominantly one-time interest and non-transparent products can follow different rules, including
analytical or full differential taxation. [Swiss Federal Tax Administration, Circular No. 15](https://www.estv.admin.ch/dam/de/sd-web/2H5NhZhB6Evl/dbst-ks-2007-1-015-dvs-de.pdf)

That is narrower than “the coupon was capital gains”. The document separates a taxable bond return
from an option-premium component and imposes conditions. It also addresses federal direct tax,
withholding tax and stamp duties under Swiss rules. It says nothing about the treatment of a
Wildcat vault, a token holder in another country or a particular offering in 2026. Any live series
needs advice for the exact issuer, holder and documents.

US filings show why tax language cannot be copied across borders. Reverse-convertible issuers have
described possible deposit-plus-option treatment while warning that the IRS could instead apply
contingent-payment debt rules, changing the timing and character of income. [SEC-filed reverse
convertible supplement](https://www.sec.gov/Archives/edgar/data/312070/000119312507078065/d424b3.htm)

## The family tree

| Form | Debt leg | Reference leg | Common extra feature | What not to assume |
| --- | --- | --- | --- | --- |
| Plain reverse convertible | Issuer note | Short put on one asset | Cash or share redemption | Principal protection |
| Barrier reverse convertible | Issuer note | Short put activated by a barrier | Continuous, daily or maturity observation | That loss starts at the barrier |
| Worst-of reverse convertible | Issuer note | Short put on the weakest basket member | Higher headline coupon | Diversification from a correlated basket |
| Autocallable reverse convertible | Issuer note | Short downside option | Early call on favourable observations | A fixed term or reinvestment outcome |
| German *Aktienanleihe* | Issuer note | Equity-linked redemption | German retail wrapper and documents | Swiss tax treatment |
| UK precipice/high-income bond | Issuer or structured-product claim | Index or equity downside | Sometimes geared capital loss | One standard payoff or good conduct history |
| US ELKS/reverse exchangeable | Issuer note | Equity-linked cash or share redemption | Filing-specific calls and tax characterisation | Deposit insurance, liquidity or simple tax treatment |
| Wildcat BTC example | Sole-lender vault claim | Cash rebate linked to one BTC/USD maturity fixing | Recovery branch pays notes only | Bank credit, physical BTC delivery or periodic coupons |

## What Wildcat keeps and what it changes

The prototype keeps the economic split. Investors fund a debt claim and accept a BTC-linked
principal reduction after complete borrower performance. The borrower receives the value of that
reduction as a rebate, which is the onchain cash analogue of the put payoff.

It changes the issuer machinery. Wildcat accounts for the loan, interest, repayment, delinquency and
withdrawal batches. The vault is the only direct lender and issues the notes. Chainlink supplies the
primary BTC/USD evidence. There is no bank calculation agent with discretion to deliver shares.

It also changes the failure result. A classic note remains an unsecured issuer obligation, so the
investor takes issuer credit risk. The prototype makes that credit layer visible in Wildcat. If the
market does not pay in full, the vault follows recovery and gives the borrower no BTC-linked rebate.
Collected recovery belongs to noteholders. That keeps default from becoming an accidental second
source of borrower relief.

## Lessons carried into the product material

- Start with the maximum principal loss and the barrier cliff, not the yield.
- Describe the instrument as borrower credit plus a put sold by the lender.
- Keep the reference-asset observation rule beside the payoff, including equality and market-hours
  rules.
- Treat liquidity, issuer credit and oracle failure as separate risks.
- Do not transfer a tax label, suitability conclusion or index licence from one wrapper or country
  to another.
- Keep promotional benefit and adverse scenario in the same field of view. The precipice-bond and
  US enforcement records show why.

## Source limits

This review favoured regulators, tax authorities, offering documents and contemporary reporting.
It did not find primary evidence for every trade name sometimes grouped with reverse convertibles,
including YEELDS, STRIDES and PERQS, or for a precise first-ever reverse-convertible issuance. Those
labels should be added only with the original prospectus or a reliable contemporary source.

The checked bibliography and source-selection rules are in the [research source
index](sources.md).
