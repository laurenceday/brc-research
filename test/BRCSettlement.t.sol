// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { BRCActivationTest } from "./BRCActivation.t.sol";
import { BRCNoteVault } from "../src/BRCNoteVault.sol";
import { BRCState } from "../src/BRCSeries.sol";

contract BRCSettlementTest is BRCActivationTest {
  address internal constant ALICE = address(0xA11CE);
  address internal constant BOB = address(0xB0B);

  function testSettlesWithoutBreachAndRedeemsFullPool() external {
    _activateAndRecordMaturity(80_000e8);
    _closeExecuteAndFinalize();

    assertEq(vault.borrowerRebate(), 0);
    assertEq(vault.noteholderReserve(), vault.wildcatProceeds());
    assertTrue(vault.borrowerRebateClaimed());

    uint256 expectedAssets = vault.noteholderReserve();
    uint256 recipientBalanceBefore = asset.balanceOf(ALICE);
    vault.redeem(NOTIONAL, ALICE);

    assertEq(asset.balanceOf(ALICE) - recipientBalanceBefore, expectedAssets);
    assertEq(vault.redeemedAssets(), expectedAssets);
    assertEq(vault.totalSupply(), 0);
    assertEq(uint256(vault.state()), uint256(BRCState.Settled));
  }

  function testExactBarrierPaysRebateAndLeavesInterestToNotes() external {
    _activateAndRecordMaturity(60_000e8);
    _closeExecuteAndFinalize();

    uint256 expectedRebate = uint256(NOTIONAL) * 40 / 100;
    assertEq(vault.borrowerRebate(), expectedRebate);
    assertEq(vault.noteholderReserve() + expectedRebate, vault.wildcatProceeds());
    assertGt(vault.noteholderReserve(), uint256(NOTIONAL) - expectedRebate);

    uint256 borrowerBalanceBefore = asset.balanceOf(address(this));
    vault.claimBorrowerRebate();
    assertEq(asset.balanceOf(address(this)) - borrowerBalanceBefore, expectedRebate);

    vault.redeem(NOTIONAL, address(this));
    assertEq(uint256(vault.state()), uint256(BRCState.Settled));
  }

  function testDeepBreachUsesFacePrincipalNotCollectedInterest() external {
    _activateAndRecordMaturity(55_000e8);
    _closeExecuteAndFinalize();

    assertEq(vault.borrowerRebate(), uint256(NOTIONAL) * 45 / 100);
    assertEq(vault.borrowerRebate() + vault.noteholderReserve(), vault.wildcatProceeds());
  }

  function testCanQueueAtMaturityBeforeFixingButCannotFinalizeOpenMarket() external {
    vault.activate();
    vm.expectRevert(BRCNoteVault.MaturityNotReached.selector);
    vault.queueSettlementWithdrawal(new uint32[](0));

    vm.warp(maturity);
    vault.queueSettlementWithdrawal(new uint32[](0));

    vm.expectRevert(BRCNoteVault.MaturityFixingMissing.selector);
    vault.finalizeSettlement();

    _recordMaturity(80_000e8);

    vm.expectRevert(BRCNoteVault.IncompleteMarketPerformance.selector);
    vault.finalizeSettlement();
  }

  function testCannotExecutePendingBatchBeforeClose() external {
    _activateAndRecordMaturity(80_000e8);
    uint32 expiry = vault.queueSettlementWithdrawal(new uint32[](0));

    vm.expectRevert();
    vault.executeSettlementWithdrawal(expiry);
  }

  function testCannotQueueLiveBalancePastUint32SettlementHorizon() external {
    _activateAndRecordMaturity(80_000e8);
    vm.warp(uint256(type(uint32).max) - WITHDRAWAL_BATCH_DURATION);

    vm.expectRevert(BRCNoteVault.SettlementQueueWindowClosed.selector);
    vault.queueSettlementWithdrawal(new uint32[](0));

    assertEq(uint256(vault.state()), uint256(BRCState.Active));
    assertEq(market.scaledBalanceOf(address(vault)), vault.activatedScaledAmount());
  }

  function testQueuesLiveBalanceAtLastSafeUint32SettlementTimestamp() external {
    _activateAndRecordMaturity(80_000e8);
    vm.warp(uint256(type(uint32).max) - WITHDRAWAL_BATCH_DURATION - 1);

    uint32 expiry = vault.queueSettlementWithdrawal(new uint32[](0));

    assertEq(expiry, type(uint32).max - 1);
    assertEq(uint256(vault.state()), uint256(BRCState.Withdrawing));
  }

  function testAdoptsMultipleBatchesIncludingPriorWithdrawal() external {
    _activateAndRecordMaturity(80_000e8);
    uint256 firstAmount = market.balanceOf(address(vault)) / 2;
    vm.prank(address(vault));
    uint32 firstExpiry = market.queueWithdrawal(firstAmount);

    vm.warp(uint256(firstExpiry) + 1);
    market.executeWithdrawal(address(vault), firstExpiry);
    vm.prank(address(vault));
    uint32 secondExpiry = market.queueFullWithdrawal();

    _closeMarket();
    market.executeWithdrawal(address(vault), secondExpiry);

    uint32[] memory adoptedExpiries = new uint32[](2);
    adoptedExpiries[0] = firstExpiry;
    adoptedExpiries[1] = secondExpiry;
    vault.queueSettlementWithdrawal(adoptedExpiries);
    vault.finalizeSettlement();

    assertEq(vault.settlementBatchExpiries(0), firstExpiry);
    assertEq(vault.settlementBatchExpiries(1), secondExpiry);
    assertEq(vault.wildcatProceeds(), vault.noteholderReserve());
  }

  function testInterestBeforeAndAfterPrincipalRepaymentStaysWithNotes() external {
    vault.activate();
    uint256 borrowed = market.borrowableAssets();
    market.borrow(borrowed);

    vm.warp(block.timestamp + 10 days);
    asset.approve(address(market), type(uint256).max);
    market.repay(borrowed);

    _recordMaturity(60_000e8);
    _closeExecuteAndFinalize();

    uint256 expectedRebate = uint256(NOTIONAL) * 40 / 100;
    assertEq(vault.borrowerRebate(), expectedRebate);
    assertGt(vault.noteholderReserve(), uint256(NOTIONAL) - expectedRebate);
  }

  function testRedemptionOrderAndTransfersDoNotChangePool() external {
    _activateAndRecordMaturity(80_000e8);
    _closeExecuteAndFinalize();

    vault.setEligible(ALICE, true);
    vault.setEligible(BOB, true);
    uint256 aliceNotes = NOTIONAL / 3;
    vault.transfer(ALICE, aliceNotes);
    vault.transfer(BOB, NOTIONAL - aliceNotes);

    uint256 reserve = vault.noteholderReserve();
    vm.prank(BOB);
    uint256 bobAssets = vault.redeem(NOTIONAL - aliceNotes, BOB);
    vm.prank(ALICE);
    uint256 aliceAssets = vault.redeem(aliceNotes, ALICE);

    assertEq(aliceAssets + bobAssets, reserve);
    assertEq(vault.redeemedAssets(), reserve);
    assertEq(uint256(vault.state()), uint256(BRCState.Settled));
  }

  function testDonationDoesNotIncreaseSettlementPool() external {
    _activateAndRecordMaturity(80_000e8);
    uint32 expiry = vault.queueSettlementWithdrawal(new uint32[](0));

    uint256 donation = 123e6;
    asset.mint(address(vault), donation);
    _closeMarket();
    vault.executeSettlementWithdrawal(expiry);
    vault.finalizeSettlement();

    uint256 proceeds = vault.wildcatProceeds();
    assertEq(vault.noteholderReserve(), proceeds);
    vault.redeem(NOTIONAL, address(this));
    assertEq(asset.balanceOf(address(vault)), donation);
  }

  function testRepeatedSettlementAndClaimsFailClosed() external {
    _activateAndRecordMaturity(60_000e8);
    _closeExecuteAndFinalize();

    vm.expectRevert(BRCNoteVault.WrongState.selector);
    vault.queueSettlementWithdrawal(new uint32[](0));
    vm.expectRevert(BRCNoteVault.WrongState.selector);
    vault.finalizeSettlement();

    vault.claimBorrowerRebate();
    vm.expectRevert(BRCNoteVault.RebateAlreadyClaimed.selector);
    vault.claimBorrowerRebate();
  }

  function testAdoptsSanctionsWithdrawalQueuedAndExecutedBeforeSettlement() external {
    _activateAndRecordMaturity(80_000e8);
    chainalysis.setSanctioned(address(vault), true);
    market.nukeFromOrbit(address(vault));
    uint32 expiry = market.previousState().pendingWithdrawalExpiry;
    assertEq(market.scaledBalanceOf(address(vault)), 0);

    _closeMarket();
    chainalysis.setSanctioned(address(vault), false);
    market.executeWithdrawal(address(vault), expiry);

    uint32[] memory adoptedExpiries = new uint32[](1);
    adoptedExpiries[0] = expiry;
    vault.queueSettlementWithdrawal(adoptedExpiries);
    vault.finalizeSettlement();

    assertEq(vault.wildcatProceeds(), vault.noteholderReserve());
    vault.redeem(NOTIONAL, address(this));
    assertEq(uint256(vault.state()), uint256(BRCState.Settled));
  }

  function _activateAndRecordMaturity(uint128 maturityPrice) internal {
    vault.activate();
    _recordMaturity(maturityPrice);
  }

  function _recordMaturity(uint128 maturityPrice) internal {
    vm.warp(maturity);
    feed.setRound(2, int256(uint256(maturityPrice)), maturity, maturity, 2);
    vault.fixingOracle().recordMaturityFixing(_round(1, 2), _round(1, 1));
  }

  function _closeExecuteAndFinalize() internal {
    uint32 expiry = vault.queueSettlementWithdrawal(new uint32[](0));
    _closeMarket();
    vault.executeSettlementWithdrawal(expiry);
    vault.finalizeSettlement();
  }

  function _closeMarket() internal {
    asset.mint(address(this), NOTIONAL);
    asset.approve(address(market), type(uint256).max);
    market.closeMarket();
  }

  function _round(uint16 phase, uint64 aggregatorRound) internal pure returns (uint80) {
    return (uint80(phase) << 64) | aggregatorRound;
  }
}
