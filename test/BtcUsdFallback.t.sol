// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { BRCFallbackConfig } from "../src/BRCFallback.sol";
import { BtcUsdFixingOracle } from "../src/BtcUsdFixingOracle.sol";
import { AggregatorV3Interface } from "../src/interfaces/AggregatorV3Interface.sol";
import { MockAggregatorV3 } from "./mocks/MockAggregatorV3.sol";
import { MockChainlinkProxy } from "./mocks/MockChainlinkProxy.sol";

contract BtcUsdFallbackTest is Test {
  uint256 internal constant RATIFIER_ONE_KEY = 0xA11CE;
  uint256 internal constant RATIFIER_TWO_KEY = 0xB0B;
  uint256 internal constant RATIFIER_THREE_KEY = 0xCAFE;
  uint32 internal constant MAX_OBSERVATION_DELAY = 1 hours;
  uint32 internal constant WAITING_PERIOD = 1 days;
  uint32 internal constant CHALLENGE_PERIOD = 1 days;
  bytes32 internal constant SOURCE_ID = keccak256("BTC fallback");
  bytes32 internal constant EVIDENCE_HASH = keccak256("fallback evidence");

  MockAggregatorV3 internal aggregator;
  MockChainlinkProxy internal proxy;
  BtcUsdFixingOracle internal oracle;
  BtcUsdFixingOracle internal otherOracle;
  uint40 internal maturity;

  function setUp() external {
    vm.warp(10 days);
    maturity = uint40(block.timestamp + 1 days);
    aggregator = new MockAggregatorV3(8, "BTC / USD");
    aggregator.setRound(1, 100_000e8, block.timestamp, block.timestamp, 1);
    proxy = new MockChainlinkProxy(8, "BTC / USD");
    proxy.setPhase(1, aggregator);
    oracle = _deploy(_config());
    otherOracle = _deploy(_config());
    oracle.recordInitialFixing();
    otherOracle.recordInitialFixing();
  }

  function testFallbackWaitsForBothDelaysAndValidatesEvidence() external {
    vm.warp(uint256(maturity) + MAX_OBSERVATION_DELAY + WAITING_PERIOD - 1);
    vm.startPrank(vm.addr(RATIFIER_ONE_KEY));
    vm.expectRevert(BtcUsdFixingOracle.FallbackNotReady.selector);
    oracle.proposeFallback(90_000e8, maturity, SOURCE_ID, EVIDENCE_HASH);

    vm.warp(oracle.fallbackAvailableAt());
    vm.expectRevert(BtcUsdFixingOracle.InvalidFallbackObservation.selector);
    oracle.proposeFallback(0, maturity, SOURCE_ID, EVIDENCE_HASH);
    vm.expectRevert(BtcUsdFixingOracle.InvalidFallbackObservation.selector);
    oracle.proposeFallback(
      90_000e8, uint40(uint256(maturity) + MAX_OBSERVATION_DELAY + 1), SOURCE_ID, EVIDENCE_HASH
    );
    vm.expectRevert(BtcUsdFixingOracle.FallbackSourceMismatch.selector);
    oracle.proposeFallback(90_000e8, maturity, bytes32(uint256(1)), EVIDENCE_HASH);
    vm.expectRevert(BtcUsdFixingOracle.InvalidFallbackEvidence.selector);
    oracle.proposeFallback(90_000e8, maturity, SOURCE_ID, bytes32(0));
    vm.stopPrank();
  }

  function testOnlyRatifierCanOccupyFallbackProposalSlot() external {
    vm.warp(oracle.fallbackAvailableAt());
    vm.expectRevert(BtcUsdFixingOracle.NotFallbackRatifier.selector);
    oracle.proposeFallback(1, maturity, SOURCE_ID, keccak256("junk"));

    vm.prank(vm.addr(RATIFIER_ONE_KEY));
    uint64 nonce = oracle.proposeFallback(90_000e8, maturity, SOURCE_ID, EVIDENCE_HASH);
    assertEq(nonce, 1);
  }

  function testThresholdAndChallengeDelayGateFinalFallback() external {
    uint64 nonce = _propose(oracle, 90_000e8, EVIDENCE_HASH);
    oracle.approveFallback(nonce, _signature(oracle, RATIFIER_ONE_KEY, nonce));

    vm.expectRevert(BtcUsdFixingOracle.FallbackChallengeActive.selector);
    oracle.finalizeFallback(nonce);

    vm.warp(block.timestamp + CHALLENGE_PERIOD);
    vm.expectRevert(BtcUsdFixingOracle.FallbackThresholdNotMet.selector);
    oracle.finalizeFallback(nonce);

    oracle.approveFallback(nonce, _signature(oracle, RATIFIER_TWO_KEY, nonce));
    BtcUsdFixingOracle.MaturityFixing memory fixing = oracle.finalizeFallback(nonce);

    assertTrue(oracle.hasMaturityFixing());
    assertTrue(oracle.maturityFixingIsFallback());
    assertEq(fixing.roundId, 0);
    assertEq(fixing.aggregator, address(0));
    assertEq(fixing.price, 90_000e8);
    assertEq(fixing.updatedAt, maturity);
  }

  function testDuplicateWrongChainAndWrongSeriesSignaturesFail() external {
    uint64 nonce = _propose(oracle, 90_000e8, EVIDENCE_HASH);
    bytes memory signature = _signature(oracle, RATIFIER_ONE_KEY, nonce);
    oracle.approveFallback(nonce, signature);
    vm.expectRevert(BtcUsdFixingOracle.FallbackAlreadyApproved.selector);
    oracle.approveFallback(nonce, signature);

    bytes memory wrongChainSignature = _signature(oracle, RATIFIER_TWO_KEY, nonce);
    vm.chainId(block.chainid + 1);
    vm.expectRevert(BtcUsdFixingOracle.NotFallbackRatifier.selector);
    oracle.approveFallback(nonce, wrongChainSignature);

    vm.chainId(block.chainid - 1);
    uint64 otherNonce = _propose(otherOracle, 90_000e8, EVIDENCE_HASH);
    bytes memory wrongSeriesSignature = _signature(otherOracle, RATIFIER_TWO_KEY, otherNonce);
    vm.expectRevert(BtcUsdFixingOracle.NotFallbackRatifier.selector);
    oracle.approveFallback(nonce, wrongSeriesSignature);
  }

  function testRatifierChallengeExpiresOldSignaturesAndAllowsReplacement() external {
    uint64 oldNonce = _propose(oracle, 90_000e8, EVIDENCE_HASH);
    bytes memory oldSignature = _signature(oracle, RATIFIER_ONE_KEY, oldNonce);
    vm.prank(vm.addr(RATIFIER_THREE_KEY));
    oracle.challengeFallback(oldNonce);

    vm.expectRevert(BtcUsdFixingOracle.NoActiveFallbackProposal.selector);
    oracle.approveFallback(oldNonce, oldSignature);

    uint64 newNonce = _propose(oracle, 89_000e8, keccak256("replacement evidence"));
    assertEq(newNonce, oldNonce + 1);
    vm.expectRevert(BtcUsdFixingOracle.WrongFallbackProposal.selector);
    oracle.approveFallback(oldNonce, oldSignature);
  }

  function testPrimaryProofCancelsPendingFallback() external {
    uint64 nonce = _propose(oracle, 90_000e8, EVIDENCE_HASH);
    oracle.approveFallback(nonce, _signature(oracle, RATIFIER_ONE_KEY, nonce));
    oracle.approveFallback(nonce, _signature(oracle, RATIFIER_TWO_KEY, nonce));

    aggregator.setRound(2, 91_000e8, maturity - 1, maturity - 1, 2);
    aggregator.setRound(3, 89_500e8, maturity, maturity, 3);
    oracle.recordMaturityFixing(_round(1, 3), _round(1, 2));

    assertTrue(oracle.hasMaturityFixing());
    assertFalse(oracle.maturityFixingIsFallback());
    (,,,,,, bool active) = oracle.fallbackProposal();
    assertFalse(active);
    vm.expectRevert(BtcUsdFixingOracle.MaturityFixingAlreadyRecorded.selector);
    oracle.finalizeFallback(nonce);
  }

  function testRejectsInvalidRatifierConfiguration() external {
    BRCFallbackConfig memory config = _config();
    config.ratifiers[1] = config.ratifiers[0];
    vm.expectRevert(BtcUsdFixingOracle.InvalidFallbackConfig.selector);
    _deploy(config);

    config = _config();
    config.threshold = 4;
    vm.expectRevert(BtcUsdFixingOracle.InvalidFallbackConfig.selector);
    _deploy(config);

    config = _config();
    config.ratifiers[1] = address(proxy);
    vm.expectRevert(BtcUsdFixingOracle.InvalidFallbackConfig.selector);
    _deploy(config);
  }

  function _propose(BtcUsdFixingOracle target, uint128 price, bytes32 evidenceHash)
    internal
    returns (uint64 nonce)
  {
    vm.warp(target.fallbackAvailableAt());
    vm.prank(vm.addr(RATIFIER_ONE_KEY));
    nonce = target.proposeFallback(price, maturity, SOURCE_ID, evidenceHash);
  }

  function _signature(BtcUsdFixingOracle target, uint256 privateKey, uint64 nonce)
    internal
    view
    returns (bytes memory signature)
  {
    bytes32 digest = target.fallbackApprovalDigest(nonce);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
    signature = abi.encodePacked(r, s, v);
  }

  function _deploy(BRCFallbackConfig memory config) internal returns (BtcUsdFixingOracle) {
    return new BtcUsdFixingOracle(
      AggregatorV3Interface(address(proxy)),
      address(this),
      8,
      keccak256("BTC / USD"),
      1 hours,
      30 seconds,
      6_000,
      maturity,
      MAX_OBSERVATION_DELAY,
      config
    );
  }

  function _config() internal view returns (BRCFallbackConfig memory config) {
    config.ratifiers = new address[](3);
    config.ratifiers[0] = vm.addr(RATIFIER_ONE_KEY);
    config.ratifiers[1] = vm.addr(RATIFIER_TWO_KEY);
    config.ratifiers[2] = vm.addr(RATIFIER_THREE_KEY);
    config.threshold = 2;
    config.waitingPeriod = WAITING_PERIOD;
    config.challengePeriod = CHALLENGE_PERIOD;
    config.sourceId = SOURCE_ID;
  }

  function _round(uint16 phase, uint64 aggregatorRoundId) internal pure returns (uint80) {
    return (uint80(phase) << 64) | aggregatorRoundId;
  }
}
