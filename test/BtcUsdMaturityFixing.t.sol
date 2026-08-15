// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { BtcUsdFixingOracle } from "../src/BtcUsdFixingOracle.sol";
import { BRCFallbackConfig } from "../src/BRCFallback.sol";
import { AggregatorV3Interface } from "../src/interfaces/AggregatorV3Interface.sol";
import { MockAggregatorV3 } from "./mocks/MockAggregatorV3.sol";
import { MockChainlinkProxy } from "./mocks/MockChainlinkProxy.sol";

contract BtcUsdMaturityFixingTest is Test {
  uint8 internal constant FEED_DECIMALS = 8;
  uint16 internal constant BARRIER_BIPS = 6_000;
  uint32 internal constant MAX_OBSERVATION_DELAY = 1 hours;
  bytes32 internal constant DESCRIPTION_HASH = keccak256("BTC / USD");

  MockAggregatorV3 internal phaseOne;
  MockChainlinkProxy internal proxy;
  BtcUsdFixingOracle internal oracle;
  uint40 internal maturity;

  function setUp() external {
    vm.warp(10 days);
    maturity = uint40(block.timestamp + 1 days);
    phaseOne = new MockAggregatorV3(FEED_DECIMALS, "BTC / USD");
    proxy = new MockChainlinkProxy(FEED_DECIMALS, "BTC / USD");
    phaseOne.setRound(1, 100_000e8, block.timestamp, block.timestamp, 1);
    proxy.setPhase(1, phaseOne);
    oracle = _deploy();
    oracle.recordInitialFixing();
  }

  function testRecordsFirstRoundAfterMaturity() external {
    phaseOne.setRound(2, 90_000e8, maturity - 1, maturity - 1, 2);
    phaseOne.setRound(3, 89_000e8, maturity + 1, maturity + 1, 3);
    vm.warp(maturity + 10);

    BtcUsdFixingOracle.MaturityFixing memory fixing =
      oracle.recordMaturityFixing(_round(1, 3), _round(1, 2));

    assertTrue(oracle.hasMaturityFixing());
    assertEq(fixing.roundId, _round(1, 3));
    assertEq(fixing.aggregator, address(phaseOne));
    assertEq(fixing.aggregatorRoundId, 3);
    assertEq(fixing.price, 89_000e8);
    assertEq(fixing.updatedAt, maturity + 1);
  }

  function testAcceptsRoundUpdatedExactlyAtMaturity() external {
    phaseOne.setRound(2, 90_000e8, maturity - 1, maturity - 1, 2);
    phaseOne.setRound(3, 89_000e8, maturity, maturity, 3);
    vm.warp(maturity);
    oracle.recordMaturityFixing(_round(1, 3), _round(1, 2));
  }

  function testRejectsLaterRoundWhenEarlierEligibleRoundExists() external {
    phaseOne.setRound(2, 90_000e8, maturity - 1, maturity - 1, 2);
    phaseOne.setRound(3, 89_000e8, maturity, maturity, 3);
    phaseOne.setRound(4, 88_000e8, maturity + 1, maturity + 1, 4);
    vm.warp(maturity + 10);

    vm.expectRevert(
      abi.encodeWithSelector(BtcUsdFixingOracle.EarlierEligibleRound.selector, _round(1, 3))
    );
    oracle.recordMaturityFixing(_round(1, 4), _round(1, 2));
  }

  function testOversizedRoundDoesNotBlockLaterValidCandidate() external {
    phaseOne.setRound(2, 90_000e8, maturity - 1, maturity - 1, 2);
    phaseOne.setRound(3, int256(uint256(type(uint128).max) + 1), maturity, maturity, 3);
    phaseOne.setRound(4, 88_000e8, maturity + 1, maturity + 1, 4);
    vm.warp(maturity + 10);

    vm.expectRevert(BtcUsdFixingOracle.ValueDoesNotFit.selector);
    oracle.recordMaturityFixing(_round(1, 3), _round(1, 2));

    BtcUsdFixingOracle.MaturityFixing memory fixing =
      oracle.recordMaturityFixing(_round(1, 4), _round(1, 2));
    assertEq(fixing.roundId, _round(1, 4));
    assertEq(fixing.price, 88_000e8);
  }

  function testRevertsOnUnreadableRoundIdWithinPhase() external {
    phaseOne.setRound(2, 90_000e8, maturity - 1, maturity - 1, 2);
    phaseOne.setRound(4, 88_000e8, maturity + 1, maturity + 1, 4);
    vm.warp(maturity + 10);

    vm.expectRevert(
      abi.encodeWithSelector(BtcUsdFixingOracle.UnreadableRound.selector, _round(1, 3))
    );
    oracle.recordMaturityFixing(_round(1, 4), _round(1, 2));
  }

  function testHandlesPhaseTransition() external {
    MockAggregatorV3 phaseTwo = new MockAggregatorV3(FEED_DECIMALS, "BTC / USD");
    phaseOne.setRound(2, 90_000e8, maturity - 1, maturity - 1, 2);
    phaseTwo.setRound(1, 89_000e8, maturity, maturity, 1);
    proxy.setPhase(2, phaseTwo);
    vm.warp(maturity + 10);

    BtcUsdFixingOracle.MaturityFixing memory fixing =
      oracle.recordMaturityFixing(_round(2, 1), _round(1, 2));
    assertEq(fixing.aggregator, address(phaseTwo));
    assertEq(fixing.aggregatorRoundId, 1);
  }

  function testGasRecordsMaturityAfterMaximumProofWalk() external {
    vm.pauseGasMetering();
    phaseOne.setRound(1, 90_000e8, maturity - 33, maturity - 33, 1);
    for (uint80 roundId = 2; roundId < 34; ++roundId) {
      phaseOne.setRound(
        roundId, 90_000e8, maturity - (34 - roundId), maturity - (34 - roundId), roundId
      );
    }
    phaseOne.setRound(34, 89_000e8, maturity, maturity, 34);
    vm.warp(maturity);
    vm.cool(address(oracle));
    vm.cool(address(proxy));
    vm.cool(address(phaseOne));

    vm.resumeGasMetering();
    uint256 gasBefore = gasleft();
    oracle.recordMaturityFixing(_round(1, 34), _round(1, 1));
    uint256 gasUsed = gasBefore - gasleft();
    vm.pauseGasMetering();

    assertLe(gasUsed, 650_000);
    assertTrue(oracle.hasMaturityFixing());
    vm.resumeGasMetering();
  }

  function testRejectsPhaseWithDifferentDecimals() external {
    MockAggregatorV3 phaseTwo = new MockAggregatorV3(18, "BTC / USD");
    phaseOne.setRound(2, 90_000e8, maturity - 1, maturity - 1, 2);
    phaseTwo.setRound(1, 89_000e18, maturity, maturity, 1);
    proxy.setPhase(2, phaseTwo);
    vm.warp(maturity);

    vm.expectRevert(
      abi.encodeWithSelector(BtcUsdFixingOracle.FeedDecimalsMismatch.selector, 18, FEED_DECIMALS)
    );
    oracle.recordMaturityFixing(_round(2, 1), _round(1, 2));
  }

  function testRejectsPhaseWithDifferentDescription() external {
    MockAggregatorV3 phaseTwo = new MockAggregatorV3(FEED_DECIMALS, "ETH / USD");
    phaseOne.setRound(2, 90_000e8, maturity - 1, maturity - 1, 2);
    phaseTwo.setRound(1, 89_000e8, maturity, maturity, 1);
    proxy.setPhase(2, phaseTwo);
    vm.warp(maturity);

    bytes32 actual = keccak256("ETH / USD");
    vm.expectRevert(
      abi.encodeWithSelector(
        BtcUsdFixingOracle.FeedDescriptionMismatch.selector, actual, DESCRIPTION_HASH
      )
    );
    oracle.recordMaturityFixing(_round(2, 1), _round(1, 2));
  }

  function testRejectsPredecessorThatIsNotPreviousPhaseTail() external {
    MockAggregatorV3 phaseTwo = new MockAggregatorV3(FEED_DECIMALS, "BTC / USD");
    phaseOne.setRound(2, 91_000e8, maturity - 2, maturity - 2, 2);
    phaseOne.setRound(3, 90_000e8, maturity - 1, maturity - 1, 3);
    phaseTwo.setRound(1, 89_000e8, maturity, maturity, 1);
    proxy.setPhase(2, phaseTwo);
    vm.warp(maturity + 10);

    vm.expectRevert(BtcUsdFixingOracle.InvalidPredecessor.selector);
    oracle.recordMaturityFixing(_round(2, 1), _round(1, 2));
  }

  function testRejectsBeforeMaturityAndCandidateOutsideWindow() external {
    phaseOne.setRound(2, 90_000e8, maturity - 2, maturity - 2, 2);
    phaseOne.setRound(3, 89_000e8, maturity - 1, maturity - 1, 3);
    vm.expectRevert(BtcUsdFixingOracle.BeforeMaturity.selector);
    oracle.recordMaturityFixing(_round(1, 3), _round(1, 2));

    vm.warp(maturity + MAX_OBSERVATION_DELAY + 10);
    vm.expectRevert(BtcUsdFixingOracle.CandidateBeforeMaturity.selector);
    oracle.recordMaturityFixing(_round(1, 3), _round(1, 2));

    phaseOne.setRound(
      3, 89_000e8, maturity + MAX_OBSERVATION_DELAY + 1, maturity + MAX_OBSERVATION_DELAY + 1, 3
    );
    vm.expectRevert(BtcUsdFixingOracle.CandidateAfterObservationDeadline.selector);
    oracle.recordMaturityFixing(_round(1, 3), _round(1, 2));
  }

  function testRejectsCandidateBeyondFutureSkew() external {
    phaseOne.setRound(2, 90_000e8, maturity - 1, maturity - 1, 2);
    phaseOne.setRound(3, 89_000e8, maturity + 31, maturity + 31, 3);
    vm.warp(maturity);

    vm.expectRevert(BtcUsdFixingOracle.FutureTimestamp.selector);
    oracle.recordMaturityFixing(_round(1, 3), _round(1, 2));
  }

  function testRejectsRepeatedSubmission() external {
    phaseOne.setRound(2, 90_000e8, maturity - 1, maturity - 1, 2);
    phaseOne.setRound(3, 89_000e8, maturity, maturity, 3);
    vm.warp(maturity);
    oracle.recordMaturityFixing(_round(1, 3), _round(1, 2));

    vm.expectRevert(BtcUsdFixingOracle.MaturityFixingAlreadyRecorded.selector);
    oracle.recordMaturityFixing(_round(1, 3), _round(1, 2));
  }

  function testRejectsOversizedProofWalk() external {
    phaseOne.setRound(1, 90_000e8, maturity - 1, maturity - 1, 1);
    phaseOne.setRound(35, 89_000e8, maturity, maturity, 35);
    vm.warp(maturity);

    vm.expectRevert(BtcUsdFixingOracle.ProofTooLong.selector);
    oracle.recordMaturityFixing(_round(1, 35), _round(1, 1));
  }

  function _deploy() internal returns (BtcUsdFixingOracle) {
    address[] memory ratifiers = new address[](1);
    ratifiers[0] = address(0xA11CE);
    return new BtcUsdFixingOracle(
      AggregatorV3Interface(address(proxy)),
      address(this),
      FEED_DECIMALS,
      DESCRIPTION_HASH,
      1 hours,
      30 seconds,
      BARRIER_BIPS,
      maturity,
      MAX_OBSERVATION_DELAY,
      BRCFallbackConfig({
        ratifiers: ratifiers,
        threshold: 1,
        waitingPeriod: 1 hours,
        challengePeriod: 1 hours,
        sourceId: keccak256("BTC fallback")
      })
    );
  }

  function _round(uint16 phase, uint64 aggregatorRoundId) internal pure returns (uint80) {
    return (uint80(phase) << 64) | aggregatorRoundId;
  }
}
