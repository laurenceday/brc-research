// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AggregatorV3Interface } from "../../src/interfaces/AggregatorV3Interface.sol";

contract MockAggregatorV3 is AggregatorV3Interface {
  struct Round {
    int256 answer;
    uint256 startedAt;
    uint256 updatedAt;
    uint80 answeredInRound;
    bool exists;
  }

  uint8 public immutable override decimals;
  string public override description;
  uint256 public constant override version = 1;
  uint80 public latestRoundId;
  bool public revertLookups;
  mapping(uint80 => Round) public rounds;

  constructor(uint8 decimals_, string memory description_) {
    decimals = decimals_;
    description = description_;
  }

  function setRevertLookups(bool value) external {
    revertLookups = value;
  }

  function setRound(
    uint80 roundId,
    int256 answer,
    uint256 startedAt,
    uint256 updatedAt,
    uint80 answeredInRound
  ) external {
    rounds[roundId] = Round(answer, startedAt, updatedAt, answeredInRound, true);
    if (roundId > latestRoundId) latestRoundId = roundId;
  }

  function getRoundData(uint80 roundId)
    public
    view
    returns (uint80, int256, uint256, uint256, uint80)
  {
    if (revertLookups || !rounds[roundId].exists) revert("No data present");
    Round memory round = rounds[roundId];
    return (roundId, round.answer, round.startedAt, round.updatedAt, round.answeredInRound);
  }

  function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
    return getRoundData(latestRoundId);
  }
}
