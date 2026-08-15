// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { BRCSettlementTest } from "./BRCSettlement.t.sol";
import { BRCNoteVault } from "../src/BRCNoteVault.sol";
import { BRCState } from "../src/BRCSeries.sol";

contract BRCRecoveryTest is BRCSettlementTest {
  function testRecoveryCannotStartBeforeContractualGracePeriod() external {
    vault.activate();
    vm.warp(maturity);
    vault.queueSettlementWithdrawal(new uint32[](0));

    vm.expectRevert(BRCNoteVault.RecoveryNotReady.selector);
    vault.enterRecovery();
  }

  function testPartialRecoveryPaysNotesAndNeverCreatesRebate() external {
    uint32 expiry = _enterQueuedDefault(false);
    vm.warp(uint256(expiry) + 1);
    uint256 firstRecovery = vault.executeRecoveryWithdrawal(expiry);
    assertGt(firstRecovery, 0);

    uint256 secondPayment = 50_000e6;
    asset.approve(address(market), type(uint256).max);
    market.repayAndProcessUnpaidWithdrawalBatches(secondPayment, 1);
    uint256 secondRecovery = vault.executeRecoveryWithdrawal(expiry);
    assertGt(secondRecovery, 0);

    vm.expectRevert(BRCNoteVault.WrongState.selector);
    vault.redeem(NOTIONAL, address(this));
    vm.expectRevert(BRCNoteVault.WrongState.selector);
    vault.claimBorrowerRebate();

    vm.warp(vault.recoveryWriteOffAt());
    vault.finalizeRecovery();

    uint256 recovered = firstRecovery + secondRecovery;
    assertEq(vault.wildcatProceeds(), recovered);
    assertEq(vault.noteholderReserve(), recovered);
    assertEq(vault.borrowerRebate(), 0);
    assertTrue(vault.borrowerRebateClaimed());

    uint256 balanceBefore = asset.balanceOf(address(this));
    assertEq(vault.redeem(NOTIONAL, address(this)), recovered);
    assertEq(asset.balanceOf(address(this)) - balanceBefore, recovered);
    assertEq(uint256(vault.state()), uint256(BRCState.Settled));

    asset.mint(address(vault), 1);
    assertEq(asset.balanceOf(address(vault)), 1);
  }

  function testValidMaturityFixingDoesNotCreateRebateInRecovery() external {
    _activateAndRecordMaturity(50_000e8);
    uint256 borrowed = market.borrowableAssets();
    market.borrow(borrowed);

    uint32 expiry = vault.queueSettlementWithdrawal(new uint32[](0));
    vm.warp(vault.recoveryEligibleAt());
    vault.enterRecovery();
    vm.warp(uint256(expiry) + 1);
    vault.executeRecoveryWithdrawal(expiry);
    vm.warp(vault.recoveryWriteOffAt());
    vault.finalizeRecovery();

    assertTrue(vault.fixingOracle().hasMaturityFixing());
    assertEq(vault.borrowerRebate(), 0);
    assertEq(vault.noteholderReserve(), vault.wildcatProceeds());
  }

  function testOnlyQueuedUnpaidSeriesCanEnterRecovery() external {
    _activateAndRecordMaturity(80_000e8);
    uint32 expiry = vault.queueSettlementWithdrawal(new uint32[](0));

    vm.warp(vault.recoveryEligibleAt());
    vault.enterRecovery();

    assertEq(vault.settlementBatchExpiries(0), expiry);
    vm.expectRevert(BRCNoteVault.WrongState.selector);
    vault.queueSettlementWithdrawal(new uint32[](0));
  }

  function testCompletePerformanceCannotBeRedirectedIntoRecovery() external {
    _activateAndRecordMaturity(55_000e8);
    uint32 expiry = vault.queueSettlementWithdrawal(new uint32[](0));
    _closeMarket();
    vault.executeSettlementWithdrawal(expiry);

    vm.warp(vault.recoveryEligibleAt());
    vm.expectRevert(BRCNoteVault.MarketPerformanceComplete.selector);
    vault.enterRecovery();

    vault.finalizeSettlement();
    assertEq(vault.borrowerRebate(), NOTIONAL * 45 / 100);
  }

  function testClosedMarketCanQueueNormallyWhileFixingIsDelayed() external {
    vault.activate();
    vm.warp(maturity);
    _closeMarket();
    vm.warp(vault.recoveryEligibleAt());

    vm.expectRevert(BRCNoteVault.WrongState.selector);
    vault.enterRecovery();

    uint32 expiry = vault.queueSettlementWithdrawal(new uint32[](0));
    vm.expectRevert(BRCNoteVault.MarketPerformanceComplete.selector);
    vault.enterRecovery();
    vm.warp(uint256(expiry) + 1);
    vault.executeSettlementWithdrawal(expiry);
    vm.expectRevert(BRCNoteVault.MaturityFixingMissing.selector);
    vault.finalizeSettlement();
    feed.setRound(2, 55_000e8, maturity, maturity, 2);
    vault.fixingOracle().recordMaturityFixing(_round(1, 2), _round(1, 1));
    vault.finalizeSettlement();
    assertEq(vault.borrowerRebate(), NOTIONAL * 45 / 100);
  }

  function testPaidPositionCanFinalizeWithoutBorrowerClosingMarket() external {
    _activateAndRecordMaturity(55_000e8);
    uint32 expiry = vault.queueSettlementWithdrawal(new uint32[](0));
    asset.mint(address(this), NOTIONAL * 2);
    asset.approve(address(market), type(uint256).max);
    market.repayAndProcessUnpaidWithdrawalBatches(NOTIONAL * 2, 1);
    vm.warp(uint256(expiry) + 1);
    vault.executeSettlementWithdrawal(expiry);

    assertFalse(market.previousState().isClosed);
    assertEq(market.totalSupply(), 0);
    vault.finalizeSettlement();
    assertEq(vault.borrowerRebate(), NOTIONAL * 45 / 100);
  }

  function testLateRecoveryCannotFinalizeBeforeBatchExpiresAndCollectsPaidAmount() external {
    vault.activate();
    uint256 borrowed = market.borrowableAssets();
    market.borrow(borrowed);
    vm.warp(vault.recoveryWriteOffAt());
    uint32 expiry = vault.queueSettlementWithdrawal(new uint32[](0));
    vault.enterRecovery();

    vm.expectRevert(BRCNoteVault.WithdrawalNotReady.selector);
    vault.finalizeRecovery();

    vm.warp(uint256(expiry) + 1);
    vault.finalizeRecovery();
    assertGt(vault.wildcatProceeds(), 0);
    assertEq(vault.noteholderReserve(), vault.wildcatProceeds());
  }

  function testRecoveryCannotFinalizeBeforeWriteOffEligibility() external {
    vault.activate();
    vm.warp(maturity);
    vault.queueSettlementWithdrawal(new uint32[](0));
    vm.warp(vault.recoveryEligibleAt());
    vault.enterRecovery();

    vm.expectRevert(BRCNoteVault.RecoveryNotReady.selector);
    vault.finalizeRecovery();
  }

  function testGasFinalizesRecoveryWithMaximumAdoptedBatches() external {
    vm.pauseGasMetering();
    vault.activate();
    market.borrow(market.borrowableAssets());
    vm.warp(maturity);

    uint32[] memory adoptedExpiries = new uint32[](8);
    for (uint256 i; i < adoptedExpiries.length; ++i) {
      uint256 activeBalance = market.balanceOf(address(vault));
      vm.prank(address(vault));
      adoptedExpiries[i] = market.queueWithdrawal(activeBalance / 100);
      vm.warp(uint256(adoptedExpiries[i]) + 1);
    }

    uint32 liveExpiry = vault.queueSettlementWithdrawal(adoptedExpiries);
    if (block.timestamp < vault.recoveryEligibleAt()) vm.warp(vault.recoveryEligibleAt());
    vault.enterRecovery();
    uint256 finalizationTime = vault.recoveryWriteOffAt();
    if (finalizationTime <= liveExpiry) finalizationTime = uint256(liveExpiry) + 1;
    vm.warp(finalizationTime);
    vm.cool(address(vault));
    vm.cool(address(market));
    vm.cool(address(asset));
    vm.cool(address(hooks));
    vm.cool(address(sanctionsSentinel));
    vm.cool(address(chainalysis));
    vm.cool(address(archController));
    vm.cool(address(hooksFactory));

    vm.resumeGasMetering();
    uint256 gasBefore = gasleft();
    vault.finalizeRecovery();
    uint256 gasUsed = gasBefore - gasleft();
    vm.pauseGasMetering();

    assertLe(gasUsed, 1_500_000);
    for (uint256 i; i < adoptedExpiries.length; ++i) {
      assertGt(
        market.getAccountWithdrawalStatus(address(vault), adoptedExpiries[i])
        .normalizedAmountWithdrawn,
        0
      );
    }
    assertEq(uint256(vault.state()), uint256(BRCState.Redeemable));
    vm.resumeGasMetering();
  }

  function _enterQueuedDefault(bool recordFixing) internal returns (uint32 expiry) {
    vault.activate();
    uint256 borrowed = market.borrowableAssets();
    market.borrow(borrowed);
    if (recordFixing) _recordMaturity(80_000e8);
    else vm.warp(maturity);
    expiry = vault.queueSettlementWithdrawal(new uint32[](0));
    vm.warp(vault.recoveryEligibleAt());
    vault.enterRecovery();
  }
}
