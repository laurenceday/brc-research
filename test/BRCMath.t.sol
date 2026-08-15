// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { BRCMath } from "../src/BRCMath.sol";
import { BRCSeriesTerms } from "../src/BRCSeries.sol";

contract BRCMathHarness {
  using BRCMath for BRCSeriesTerms;

  function principalSlash(BRCSeriesTerms memory terms, uint128 maturityPrice)
    external
    pure
    returns (uint128)
  {
    return terms.principalSlash(maturityPrice);
  }
}

contract BRCMathTest is Test {
  using BRCMath for BRCSeriesTerms;

  BRCSeriesTerms internal terms;
  BRCMathHarness internal harness;

  function setUp() external {
    harness = new BRCMathHarness();
    terms = BRCSeriesTerms({
      notional: 1_000_000e6,
      strike: 100_000e8,
      barrier: 60_000e8,
      maturity: uint40(block.timestamp + 90 days),
      settlementAssetDecimals: 6
    });
  }

  function testNoBreachAboveBarrier() external view {
    assertEq(terms.principalSlash(60_000e8 + 1), 0);
  }

  function testBarrierEqualityBreaches() external view {
    assertEq(terms.principalSlash(60_000e8), 400_000e6);
  }

  function testDeepBreach() external view {
    assertEq(terms.principalSlash(55_000e8), 450_000e6);
  }

  function testZeroPriceSlashesAllPrincipal() external view {
    assertEq(terms.principalSlash(0), terms.notional);
  }

  function testStrikeAndHigherPricesDoNotSlash() external view {
    assertEq(terms.principalSlash(terms.strike), 0);
    assertEq(terms.principalSlash(terms.strike + 1), 0);
  }

  function testInterestStaysInNoteholderPool() external view {
    uint128 collected = terms.notional + 12_000e6;
    uint128 rebate = terms.borrowerRebate(55_000e8, terms.notional);
    assertEq(rebate, 450_000e6);
    assertEq(BRCMath.noteholderPool(collected, rebate), 562_000e6);
  }

  function testOddValuesRoundDown() external pure {
    BRCSeriesTerms memory oddTerms = BRCSeriesTerms({
      notional: 101, strike: 7, barrier: 6, maturity: 1, settlementAssetDecimals: 6
    });

    assertEq(oddTerms.principalSlash(5), 28);
    assertEq(BRCMath.proRata(101, 1, 3), 33);
  }

  function testFuzzSlashMatchesReference(
    uint128 notional,
    uint128 strike,
    uint128 barrier,
    uint128 maturityPrice
  ) external pure {
    notional = uint128(bound(notional, 1, type(uint128).max));
    strike = uint128(bound(strike, 1, type(uint128).max));
    barrier = uint128(bound(barrier, 0, strike));

    BRCSeriesTerms memory fuzzTerms = BRCSeriesTerms({
      notional: notional, strike: strike, barrier: barrier, maturity: 1, settlementAssetDecimals: 6
    });

    uint128 actual = fuzzTerms.principalSlash(maturityPrice);
    uint128 expected;
    if (maturityPrice <= barrier && maturityPrice < strike) {
      expected = uint128((uint256(notional) * (strike - maturityPrice)) / strike);
    }

    assertEq(actual, expected);
    assertLe(actual, notional);
  }

  function testFuzzLowerBreachedPriceCannotReduceSlash(uint128 lowerPrice, uint128 higherPrice)
    external
    view
  {
    lowerPrice = uint128(bound(lowerPrice, 0, terms.barrier));
    higherPrice = uint128(bound(higherPrice, lowerPrice, terms.barrier));
    assertGe(terms.principalSlash(lowerPrice), terms.principalSlash(higherPrice));
  }

  function testFuzzRedemptionsCannotExceedPool(uint128 pool, uint128 firstNotes, uint128 totalNotes)
    external
    pure
  {
    totalNotes = uint128(bound(totalNotes, 1, type(uint128).max));
    firstNotes = uint128(bound(firstNotes, 0, totalNotes));
    uint128 secondNotes = totalNotes - firstNotes;

    uint128 first = BRCMath.proRata(pool, firstNotes, totalNotes);
    uint128 second = BRCMath.proRata(pool, secondNotes, totalNotes);
    assertLe(uint256(first) + second, pool);
  }

  function testRejectsMalformedTerms() external {
    terms.notional = 0;
    vm.expectRevert(BRCMath.ZeroNotional.selector);
    harness.principalSlash(terms, 0);
  }
}
