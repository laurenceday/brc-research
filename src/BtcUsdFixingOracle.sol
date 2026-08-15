// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { BRCMath } from "./BRCMath.sol";
import { AggregatorV3Interface } from "./interfaces/AggregatorV3Interface.sol";
import { IChainlinkAggregatorProxy } from "./interfaces/IChainlinkAggregatorProxy.sol";

contract BtcUsdFixingOracle {
  struct InitialFixing {
    uint80 roundId;
    uint128 price;
    uint256 updatedAt;
  }

  struct MaturityFixing {
    uint80 roundId;
    address aggregator;
    uint64 aggregatorRoundId;
    uint128 price;
    uint256 updatedAt;
  }

  struct RoundReference {
    uint16 phase;
    uint64 aggregatorRoundId;
    address aggregator;
  }

  enum MaturityRoundStatus {
    Valid,
    InvalidAnswer,
    BeforeMaturity,
    AfterObservationDeadline,
    FutureTimestamp,
    IncompleteRound,
    ValueDoesNotFit
  }

  error ZeroAddress();
  error FeedDecimalsMismatch(uint8 actual, uint8 expected);
  error FeedDescriptionMismatch(bytes32 actual, bytes32 expected);
  error NotRecorder();
  error InitialFixingAlreadyRecorded();
  error InvalidAnswer();
  error InvalidTimestamp();
  error FutureTimestamp();
  error StaleRound();
  error IncompleteRound();
  error InvalidRoundId();
  error ValueDoesNotFit();
  error ZeroMaturity();
  error MaturityFixingAlreadyRecorded();
  error InitialFixingNotRecorded();
  error BeforeMaturity();
  error CandidateBeforeMaturity();
  error CandidateAfterObservationDeadline();
  error InvalidPredecessor();
  error InvalidRoundEvidence();
  error InvalidPhaseTransition();
  error MissingPhaseAggregator();
  error ProofTooLong();
  error EarlierEligibleRound(uint80 roundId);
  error InitialFixingAfterMaturity();
  error UnreadableRound(uint80 roundId);

  AggregatorV3Interface public immutable feed;
  address public immutable recorder;
  uint8 public immutable expectedDecimals;
  bytes32 public immutable expectedDescriptionHash;
  uint32 public immutable maxInitialAge;
  uint32 public immutable maxFutureSkew;
  uint16 public immutable barrierBips;
  uint40 public immutable maturity;
  uint32 public immutable maxObservationDelay;

  bool public hasInitialFixing;
  InitialFixing public initialFixing;
  uint128 public strike;
  uint128 public barrier;
  bool public hasMaturityFixing;
  MaturityFixing public maturityFixing;

  event InitialFixingRecorded(uint80 indexed roundId, uint128 price, uint256 updatedAt);
  event MaturityFixingRecorded(
    uint80 indexed roundId,
    address indexed aggregator,
    uint64 aggregatorRoundId,
    uint128 price,
    uint256 updatedAt
  );

  constructor(
    AggregatorV3Interface feed_,
    address recorder_,
    uint8 expectedDecimals_,
    bytes32 expectedDescriptionHash_,
    uint32 maxInitialAge_,
    uint32 maxFutureSkew_,
    uint16 barrierBips_,
    uint40 maturity_,
    uint32 maxObservationDelay_
  ) {
    if (address(feed_) == address(0) || recorder_ == address(0)) {
      revert ZeroAddress();
    }
    if (maturity_ == 0) revert ZeroMaturity();

    feed = feed_;
    recorder = recorder_;
    expectedDecimals = expectedDecimals_;
    expectedDescriptionHash = expectedDescriptionHash_;
    maxInitialAge = maxInitialAge_;
    maxFutureSkew = maxFutureSkew_;
    barrierBips = barrierBips_;
    maturity = maturity_;
    maxObservationDelay = maxObservationDelay_;

    _checkFeedMetadata();
    BRCMath.barrierFromBips(1, barrierBips_);
  }

  function recordMaturityFixing(uint80 candidateRoundId, uint80 predecessorRoundId)
    external
    returns (MaturityFixing memory fixing)
  {
    if (!hasInitialFixing) revert InitialFixingNotRecorded();
    if (hasMaturityFixing) revert MaturityFixingAlreadyRecorded();
    if (block.timestamp < maturity) revert BeforeMaturity();

    RoundReference memory candidate = _validateMaturityProof(candidateRoundId, predecessorRoundId);

    (uint80 returnedRoundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
      feed.getRoundData(candidateRoundId);
    if (returnedRoundId != candidateRoundId) revert InvalidRoundEvidence();
    uint128 price = _validateMaturityCandidate(candidateRoundId, answer, updatedAt, answeredInRound);

    fixing = MaturityFixing(
      candidateRoundId, candidate.aggregator, candidate.aggregatorRoundId, price, updatedAt
    );
    maturityFixing = fixing;
    hasMaturityFixing = true;

    emit MaturityFixingRecorded(
      candidateRoundId, candidate.aggregator, candidate.aggregatorRoundId, price, updatedAt
    );
  }

  function recordInitialFixing() external returns (InitialFixing memory fixing) {
    if (msg.sender != recorder) revert NotRecorder();
    if (hasInitialFixing) revert InitialFixingAlreadyRecorded();
    if (block.timestamp >= maturity) revert InitialFixingAfterMaturity();

    _checkFeedMetadata();
    (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
      feed.latestRoundData();
    uint128 price = _validateInitialRound(roundId, answer, updatedAt, answeredInRound);

    fixing = InitialFixing(roundId, price, updatedAt);
    initialFixing = fixing;
    strike = price;
    barrier = BRCMath.barrierFromBips(price, barrierBips);
    hasInitialFixing = true;

    emit InitialFixingRecorded(roundId, price, updatedAt);
  }

  function _checkFeedMetadata() internal view {
    _checkAggregatorMetadata(address(feed));
  }

  function _checkAggregatorMetadata(address aggregator) internal view {
    uint8 actualDecimals = AggregatorV3Interface(aggregator).decimals();
    if (actualDecimals != expectedDecimals) {
      revert FeedDecimalsMismatch(actualDecimals, expectedDecimals);
    }

    bytes32 actualDescriptionHash =
      keccak256(bytes(AggregatorV3Interface(aggregator).description()));
    if (actualDescriptionHash != expectedDescriptionHash) {
      revert FeedDescriptionMismatch(actualDescriptionHash, expectedDescriptionHash);
    }
  }

  function _validateInitialRound(
    uint80 roundId,
    int256 answer,
    uint256 updatedAt,
    uint80 answeredInRound
  ) internal view returns (uint128) {
    if (answer <= 0) revert InvalidAnswer();
    if (roundId == 0) revert InvalidRoundId();
    if (updatedAt == 0) revert InvalidTimestamp();
    if (updatedAt >= maturity) revert InitialFixingAfterMaturity();
    if (updatedAt > block.timestamp + maxFutureSkew) revert FutureTimestamp();
    if (answeredInRound < roundId) revert IncompleteRound();
    if (updatedAt < block.timestamp && block.timestamp - updatedAt > maxInitialAge) {
      revert StaleRound();
    }

    // The positivity check above makes the signed-to-unsigned conversion safe.
    // forge-lint: disable-next-line(unsafe-typecast)
    uint256 unsignedAnswer = uint256(answer);
    if (unsignedAnswer > type(uint128).max) revert ValueDoesNotFit();
    // The explicit bound above makes the narrowing conversion safe.
    // forge-lint: disable-next-line(unsafe-typecast)
    return uint128(unsignedAnswer);
  }

  function _validatePredecessor(
    uint80 roundId,
    int256 answer,
    uint256 updatedAt,
    uint80 answeredInRound
  ) internal view {
    if (answer <= 0 || updatedAt == 0 || updatedAt >= maturity || answeredInRound < roundId) {
      revert InvalidPredecessor();
    }
  }

  function _validateMaturityProof(uint80 candidateRoundId, uint80 predecessorRoundId)
    internal
    view
    returns (RoundReference memory candidate)
  {
    candidate = _resolveRound(candidateRoundId);
    _checkAggregatorMetadata(candidate.aggregator);
    RoundReference memory predecessor = _resolveRound(predecessorRoundId);

    (uint80 returnedRoundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
      feed.getRoundData(predecessorRoundId);
    if (returnedRoundId != predecessorRoundId) revert InvalidRoundEvidence();
    _validatePredecessor(predecessorRoundId, answer, updatedAt, answeredInRound);

    if (candidate.phase == predecessor.phase) {
      if (candidate.aggregatorRoundId <= predecessor.aggregatorRoundId) {
        revert InvalidRoundEvidence();
      }
      _assertNoEarlierEligible(
        candidate.phase, predecessor.aggregatorRoundId + 1, candidate.aggregatorRoundId
      );
      return candidate;
    }

    if (candidate.phase != predecessor.phase + 1) revert InvalidPhaseTransition();
    _validatePreviousPhaseTail(predecessor.aggregatorRoundId, predecessor.aggregator);
    _assertNoEarlierEligible(candidate.phase, 1, candidate.aggregatorRoundId);
  }

  function _validateMaturityCandidate(
    uint80 roundId,
    int256 answer,
    uint256 updatedAt,
    uint80 answeredInRound
  ) internal view returns (uint128) {
    MaturityRoundStatus status = _maturityRoundStatus(roundId, answer, updatedAt, answeredInRound);
    if (status == MaturityRoundStatus.InvalidAnswer) revert InvalidAnswer();
    if (status == MaturityRoundStatus.BeforeMaturity) revert CandidateBeforeMaturity();
    if (status == MaturityRoundStatus.AfterObservationDeadline) {
      revert CandidateAfterObservationDeadline();
    }
    if (status == MaturityRoundStatus.FutureTimestamp) revert FutureTimestamp();
    if (status == MaturityRoundStatus.IncompleteRound) revert IncompleteRound();
    if (status == MaturityRoundStatus.ValueDoesNotFit) revert ValueDoesNotFit();

    // The positivity check above makes the signed-to-unsigned conversion safe.
    // forge-lint: disable-next-line(unsafe-typecast)
    uint256 unsignedAnswer = uint256(answer);
    // The explicit bound above makes the narrowing conversion safe.
    // forge-lint: disable-next-line(unsafe-typecast)
    return uint128(unsignedAnswer);
  }

  function _maturityRoundStatus(
    uint80 roundId,
    int256 answer,
    uint256 updatedAt,
    uint80 answeredInRound
  ) internal view returns (MaturityRoundStatus) {
    if (answer <= 0) return MaturityRoundStatus.InvalidAnswer;
    if (updatedAt < maturity) return MaturityRoundStatus.BeforeMaturity;
    if (updatedAt > uint256(maturity) + maxObservationDelay) {
      return MaturityRoundStatus.AfterObservationDeadline;
    }
    if (updatedAt > block.timestamp + maxFutureSkew) return MaturityRoundStatus.FutureTimestamp;
    if (answeredInRound < roundId) return MaturityRoundStatus.IncompleteRound;
    // The positivity check above makes the signed-to-unsigned conversion safe.
    // forge-lint: disable-next-line(unsafe-typecast)
    if (uint256(answer) > type(uint128).max) return MaturityRoundStatus.ValueDoesNotFit;
    return MaturityRoundStatus.Valid;
  }

  function _validatePreviousPhaseTail(uint64 expectedLastRoundId, address aggregator)
    internal
    view
  {
    (uint80 actualRoundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
      AggregatorV3Interface(aggregator).latestRoundData();
    if (
      actualRoundId > type(uint64).max || uint64(actualRoundId) != expectedLastRoundId
        || answer <= 0 || updatedAt == 0 || answeredInRound < actualRoundId || updatedAt >= maturity
    ) revert InvalidPredecessor();
  }

  function _assertNoEarlierEligible(uint16 phase, uint64 start, uint64 end) internal view {
    if (end < start) revert InvalidRoundEvidence();
    if (end - start > 32) revert ProofTooLong();

    for (uint64 round = start; round < end; ++round) {
      uint80 roundId = _composeRoundId(phase, round);
      try feed.getRoundData(roundId) returns (
        uint80 returnedRoundId, int256 answer, uint256, uint256 updatedAt, uint80 answeredInRound
      ) {
        if (returnedRoundId != roundId) revert InvalidRoundEvidence();
        if (
          _maturityRoundStatus(roundId, answer, updatedAt, answeredInRound)
            == MaturityRoundStatus.Valid
        ) revert EarlierEligibleRound(roundId);
      } catch {
        revert UnreadableRound(roundId);
      }
    }
  }

  function _parseRoundId(uint80 roundId)
    internal
    pure
    returns (uint16 phase, uint64 aggregatorRoundId)
  {
    phase = uint16(roundId >> 64);
    aggregatorRoundId = uint64(roundId);
  }

  function _resolveRound(uint80 roundId) internal view returns (RoundReference memory roundRef) {
    (roundRef.phase, roundRef.aggregatorRoundId) = _parseRoundId(roundId);
    if (roundRef.phase == 0 || roundRef.aggregatorRoundId == 0) {
      revert InvalidRoundEvidence();
    }
    roundRef.aggregator = IChainlinkAggregatorProxy(address(feed)).phaseAggregators(roundRef.phase);
    if (roundRef.aggregator == address(0)) revert MissingPhaseAggregator();
  }

  function _composeRoundId(uint16 phase, uint64 aggregatorRoundId) internal pure returns (uint80) {
    return (uint80(phase) << 64) | aggregatorRoundId;
  }
}
