// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AggregatorV3Interface } from "../../src/interfaces/AggregatorV3Interface.sol";
import { IChainlinkAggregatorProxy } from "../../src/interfaces/IChainlinkAggregatorProxy.sol";

contract MockChainlinkProxy is IChainlinkAggregatorProxy {
  uint8 public immutable override decimals;
  string public override description;
  uint256 public constant override version = 1;
  uint16 public currentPhase;

  mapping(uint16 => address) public override phaseAggregators;

  constructor(uint8 decimals_, string memory description_) {
    decimals = decimals_;
    description = description_;
  }

  function setPhase(uint16 phase, AggregatorV3Interface aggregator) external {
    phaseAggregators[phase] = address(aggregator);
    currentPhase = phase;
  }

  function getRoundData(uint80 proxyRoundId)
    public
    view
    returns (uint80, int256, uint256, uint256, uint80)
  {
    uint16 phase = uint16(proxyRoundId >> 64);
    uint64 aggregatorRoundId = uint64(proxyRoundId);
    AggregatorV3Interface aggregator = AggregatorV3Interface(phaseAggregators[phase]);
    (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
      aggregator.getRoundData(aggregatorRoundId);
    return (
      _compose(phase, uint64(roundId)),
      answer,
      startedAt,
      updatedAt,
      _compose(phase, uint64(answeredInRound))
    );
  }

  function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
    AggregatorV3Interface aggregator = AggregatorV3Interface(phaseAggregators[currentPhase]);
    (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
      aggregator.latestRoundData();
    return (
      _compose(currentPhase, uint64(roundId)),
      answer,
      startedAt,
      updatedAt,
      _compose(currentPhase, uint64(answeredInRound))
    );
  }

  function _compose(uint16 phase, uint64 roundId) internal pure returns (uint80) {
    return (uint80(phase) << 64) | roundId;
  }
}
