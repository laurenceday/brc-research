// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { BtcUsdFixingOracle } from "../src/BtcUsdFixingOracle.sol";
import { AggregatorV3Interface } from "../src/interfaces/AggregatorV3Interface.sol";
import { MockAggregatorV3 } from "./mocks/MockAggregatorV3.sol";

contract BtcUsdFixingOracleTest is Test {
  uint8 internal constant FEED_DECIMALS = 8;
  uint32 internal constant MAX_AGE = 1 hours;
  uint32 internal constant MAX_FUTURE_SKEW = 30 seconds;
  uint16 internal constant BARRIER_BIPS = 6_000;
  bytes32 internal constant DESCRIPTION_HASH = keccak256("BTC / USD");

  MockAggregatorV3 internal feed;
  BtcUsdFixingOracle internal oracle;

  function setUp() external {
    vm.warp(10 days);
    feed = new MockAggregatorV3(FEED_DECIMALS, "BTC / USD");
    oracle = _deploy(feed, address(this), FEED_DECIMALS, DESCRIPTION_HASH);
  }

  function testRecordsFreshInitialFixingAndDerivedTerms() external {
    uint80 roundId = (uint80(2) << 64) | 1;
    feed.setRound(roundId, 100_000e8, block.timestamp, block.timestamp, roundId);

    BtcUsdFixingOracle.InitialFixing memory fixing = oracle.recordInitialFixing();

    assertTrue(oracle.hasInitialFixing());
    assertEq(fixing.roundId, roundId);
    assertEq(fixing.price, 100_000e8);
    assertEq(fixing.updatedAt, block.timestamp);
    assertEq(oracle.strike(), 100_000e8);
    assertEq(oracle.barrier(), 60_000e8);
  }

  function testRejectsWrongRecorder() external {
    feed.setRound(1, 100_000e8, block.timestamp, block.timestamp, 1);
    vm.prank(address(0xBEEF));
    vm.expectRevert(BtcUsdFixingOracle.NotRecorder.selector);
    oracle.recordInitialFixing();
  }

  function testRejectsSecondInitialFixing() external {
    feed.setRound(1, 100_000e8, block.timestamp, block.timestamp, 1);
    oracle.recordInitialFixing();
    feed.setRound(2, 90_000e8, block.timestamp, block.timestamp, 2);

    vm.expectRevert(BtcUsdFixingOracle.InitialFixingAlreadyRecorded.selector);
    oracle.recordInitialFixing();
  }

  function testRejectsInitialFixingAtOrAfterMaturity() external {
    feed.setRound(1, 100_000e8, block.timestamp, block.timestamp, 1);
    vm.warp(block.timestamp + 90 days);

    vm.expectRevert(BtcUsdFixingOracle.InitialFixingAfterMaturity.selector);
    oracle.recordInitialFixing();
  }

  function testRejectsInitialObservationAtMaturityDespiteFutureSkew() external {
    uint256 maturity = oracle.maturity();
    vm.warp(maturity - 1);
    feed.setRound(1, 100_000e8, maturity, maturity, 1);

    vm.expectRevert(BtcUsdFixingOracle.InitialFixingAfterMaturity.selector);
    oracle.recordInitialFixing();
  }

  function testRejectsZeroAndNegativeAnswers() external {
    feed.setRound(1, 0, block.timestamp, block.timestamp, 1);
    vm.expectRevert(BtcUsdFixingOracle.InvalidAnswer.selector);
    oracle.recordInitialFixing();

    feed.setRound(2, -1, block.timestamp, block.timestamp, 2);
    vm.expectRevert(BtcUsdFixingOracle.InvalidAnswer.selector);
    oracle.recordInitialFixing();
  }

  function testRejectsZeroStaleAndFutureTimestamps() external {
    feed.setRound(1, 100_000e8, 0, 0, 1);
    vm.expectRevert(BtcUsdFixingOracle.InvalidTimestamp.selector);
    oracle.recordInitialFixing();

    feed.setRound(2, 100_000e8, block.timestamp - MAX_AGE - 1, block.timestamp - MAX_AGE - 1, 2);
    vm.expectRevert(BtcUsdFixingOracle.StaleRound.selector);
    oracle.recordInitialFixing();

    feed.setRound(
      3, 100_000e8, block.timestamp + MAX_FUTURE_SKEW + 1, block.timestamp + MAX_FUTURE_SKEW + 1, 3
    );
    vm.expectRevert(BtcUsdFixingOracle.FutureTimestamp.selector);
    oracle.recordInitialFixing();
  }

  function testAcceptsTimestampAtAgeAndSkewLimits() external {
    feed.setRound(1, 100_000e8, block.timestamp - MAX_AGE, block.timestamp - MAX_AGE, 1);
    oracle.recordInitialFixing();

    BtcUsdFixingOracle second = _deploy(feed, address(this), FEED_DECIMALS, DESCRIPTION_HASH);
    feed.setRound(
      2, 100_000e8, block.timestamp + MAX_FUTURE_SKEW, block.timestamp + MAX_FUTURE_SKEW, 2
    );
    second.recordInitialFixing();
  }

  function testRejectsIncompleteRound() external {
    feed.setRound(2, 100_000e8, block.timestamp, block.timestamp, 1);
    vm.expectRevert(BtcUsdFixingOracle.IncompleteRound.selector);
    oracle.recordInitialFixing();
  }

  function testRejectsRoundZero() external {
    feed.setRound(0, 100_000e8, block.timestamp, block.timestamp, 0);
    vm.expectRevert(BtcUsdFixingOracle.InvalidRoundId.selector);
    oracle.recordInitialFixing();
  }

  function testRejectsDecimalAndDescriptionMismatch() external {
    vm.expectRevert(abi.encodeWithSelector(BtcUsdFixingOracle.FeedDecimalsMismatch.selector, 8, 18));
    _deploy(feed, address(this), 18, DESCRIPTION_HASH);

    bytes32 expected = keccak256("ETH / USD");
    vm.expectRevert(
      abi.encodeWithSelector(
        BtcUsdFixingOracle.FeedDescriptionMismatch.selector, DESCRIPTION_HASH, expected
      )
    );
    _deploy(feed, address(this), FEED_DECIMALS, expected);
  }

  function testRejectedRoundLeavesNoPartialFixing() external {
    feed.setRound(1, -1, block.timestamp, block.timestamp, 1);
    vm.expectRevert(BtcUsdFixingOracle.InvalidAnswer.selector);
    oracle.recordInitialFixing();

    assertFalse(oracle.hasInitialFixing());
    assertEq(oracle.strike(), 0);
    assertEq(oracle.barrier(), 0);
  }

  function testFuzzTimestampLimits(uint32 age, uint32 future) external {
    age = uint32(bound(age, 0, MAX_AGE));
    future = uint32(bound(future, 0, MAX_FUTURE_SKEW));

    uint256 updatedAt = age > 0 ? block.timestamp - age : block.timestamp + future;
    feed.setRound(1, 100_000e8, updatedAt, updatedAt, 1);
    oracle.recordInitialFixing();
  }

  function _deploy(
    MockAggregatorV3 feed_,
    address recorder_,
    uint8 decimals_,
    bytes32 descriptionHash_
  ) internal returns (BtcUsdFixingOracle) {
    return new BtcUsdFixingOracle(
      AggregatorV3Interface(address(feed_)),
      recorder_,
      decimals_,
      descriptionHash_,
      MAX_AGE,
      MAX_FUTURE_SKEW,
      BARRIER_BIPS,
      uint40(block.timestamp + 90 days),
      1 hours
    );
  }
}
