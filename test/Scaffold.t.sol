// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "../src/interfaces/IERC20.sol";
import { MockAggregatorV3 } from "./mocks/MockAggregatorV3.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { MockWildcatMarket } from "./mocks/MockWildcatMarket.sol";

contract ScaffoldTest is Test {
  MockERC20 internal asset;
  MockAggregatorV3 internal feed;
  MockWildcatMarket internal market;

  function setUp() external {
    asset = new MockERC20("USD Coin", "USDC", 6);
    feed = new MockAggregatorV3(8, "BTC / USD");
    market = new MockWildcatMarket(IERC20(address(asset)));
  }

  function testTokenAndMarketFixtures() external {
    asset.mint(address(this), 1_000_000e6);
    asset.approve(address(market), 1_000_000e6);
    market.deposit(1_000_000e6);
    market.queueWithdrawal(400_000e6);

    assertEq(market.balanceOf(address(this)), 600_000e6);
    assertEq(market.queued(address(this)), 400_000e6);
  }

  function testFeedFixtureCanRepresentInvalidRounds() external {
    feed.setRound(1, -1, block.timestamp, 0, 0);
    (, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = feed.latestRoundData();

    assertEq(answer, -1);
    assertEq(updatedAt, 0);
    assertEq(answeredInRound, 0);
  }

  function testTokenFixtureCanFailTransfers() external {
    asset.mint(address(this), 1);
    asset.setFailTransfers(true);
    assertFalse(asset.transfer(address(1), 1));
  }
}
