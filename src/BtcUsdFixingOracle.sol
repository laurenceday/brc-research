// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { BRCMath } from "./BRCMath.sol";
import { AggregatorV3Interface } from "./interfaces/AggregatorV3Interface.sol";

contract BtcUsdFixingOracle {
  struct InitialFixing {
    uint80 roundId;
    uint128 price;
    uint256 updatedAt;
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

  AggregatorV3Interface public immutable feed;
  address public immutable recorder;
  uint8 public immutable expectedDecimals;
  bytes32 public immutable expectedDescriptionHash;
  uint32 public immutable maxInitialAge;
  uint32 public immutable maxFutureSkew;
  uint16 public immutable barrierBips;

  bool public hasInitialFixing;
  InitialFixing public initialFixing;
  uint128 public strike;
  uint128 public barrier;

  event InitialFixingRecorded(uint80 indexed roundId, uint128 price, uint256 updatedAt);

  constructor(
    AggregatorV3Interface feed_,
    address recorder_,
    uint8 expectedDecimals_,
    bytes32 expectedDescriptionHash_,
    uint32 maxInitialAge_,
    uint32 maxFutureSkew_,
    uint16 barrierBips_
  ) {
    if (address(feed_) == address(0) || recorder_ == address(0)) {
      revert ZeroAddress();
    }

    feed = feed_;
    recorder = recorder_;
    expectedDecimals = expectedDecimals_;
    expectedDescriptionHash = expectedDescriptionHash_;
    maxInitialAge = maxInitialAge_;
    maxFutureSkew = maxFutureSkew_;
    barrierBips = barrierBips_;

    _checkFeedMetadata();
    BRCMath.barrierFromBips(1, barrierBips_);
  }

  function recordInitialFixing() external returns (InitialFixing memory fixing) {
    if (msg.sender != recorder) revert NotRecorder();
    if (hasInitialFixing) revert InitialFixingAlreadyRecorded();

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
    uint8 actualDecimals = feed.decimals();
    if (actualDecimals != expectedDecimals) {
      revert FeedDecimalsMismatch(actualDecimals, expectedDecimals);
    }

    bytes32 actualDescriptionHash = keccak256(bytes(feed.description()));
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
}
