// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Test } from "forge-std/Test.sol";
import { BRCActivationTest } from "./BRCActivation.t.sol";
import { BRCFallbackConfig } from "../src/BRCFallback.sol";
import { BRCMath } from "../src/BRCMath.sol";
import { ActivationTerms, BRCNoteVault } from "../src/BRCNoteVault.sol";
import { BRCSeriesTerms, BRCState } from "../src/BRCSeries.sol";
import { BtcUsdFixingOracle } from "../src/BtcUsdFixingOracle.sol";
import { IERC20Metadata } from "../src/interfaces/IERC20.sol";
import { MockAggregatorV3 } from "./mocks/MockAggregatorV3.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { ISingletonRoleProvider } from "v2-protocol/providers/ISingletonRoleProvider.sol";
import { LibRoleProvider, RoleProvider } from "v2-protocol/types/RoleProvider.sol";
import { WildcatMarket } from "v2-protocol/market/WildcatMarket.sol";

interface IBRCSystemFixture {
  function systemVault() external view returns (BRCNoteVault);

  function systemMarket() external view returns (WildcatMarket);

  function systemAsset() external view returns (MockERC20);

  function systemFeed() external view returns (MockAggregatorV3);

  function systemBorrower() external view returns (address);
}

/// @dev A deliberately small handler. Each action is valid in at most one lifecycle region, so
///      stateful runs spend their calls exploring order and timing rather than expected reverts.
contract BRCSystemHandler is Test {
  IBRCSystemFixture internal immutable fixture;

  address internal constant ALICE = address(0xA11CE);
  address internal constant BOB = address(0xB0B);
  uint256 internal constant RATIFIER_ONE_KEY = 0xA11CE;
  uint256 internal constant RATIFIER_TWO_KEY = 0xB0B;

  uint32 public settlementExpiry;
  uint256 public observedRedemptions;
  uint256 public primaryFixings;
  uint256 public fallbackFixings;
  uint256 public normalFinalizations;
  uint256 public recoveryFinalizations;
  uint256 public terminalSettlements;
  bool public invalidTransition;
  bool public invalidFixingMutation;
  bool public invalidRepeatedWrite;
  bool internal initialized;
  bool internal observedMaturityFixing;
  bool internal observedMaturityFixingIsFallback;
  BtcUsdFixingOracle.MaturityFixing internal recordedMaturityFixing;
  BRCState internal previousState;

  constructor(IBRCSystemFixture fixture_) {
    fixture = fixture_;
  }

  function advance(uint32 secondsForward) external {
    _beforeAction();
    vm.warp(block.timestamp + bound(secondsForward, 0, 10 days));
    _afterAction();
  }

  function advanceToMaturity() external {
    _beforeAction();
    _warpTo(fixture.systemVault().maturity());
    _afterAction();
  }

  function advanceToFallbackAvailable() external {
    _beforeAction();
    _warpTo(fixture.systemVault().fixingOracle().fallbackAvailableAt());
    _afterAction();
  }

  function advancePastFallbackChallenge() external {
    _beforeAction();
    BtcUsdFixingOracle oracle = fixture.systemVault().fixingOracle();
    (,,, uint40 proposedAt,,, bool active) = oracle.fallbackProposal();
    if (active) _warpTo(uint256(proposedAt) + oracle.fallbackChallengePeriod());
    _afterAction();
  }

  function advanceToRecoveryEligible() external {
    _beforeAction();
    _warpTo(fixture.systemVault().recoveryEligibleAt());
    _afterAction();
  }

  function advanceToRecoveryWriteOff() external {
    _beforeAction();
    BRCNoteVault vault = fixture.systemVault();
    uint256 target = vault.recoveryWriteOffAt();
    if (target <= settlementExpiry) target = uint256(settlementExpiry) + 1;
    _warpTo(target);
    _afterAction();
  }

  function advancePastSettlementExpiry() external {
    _beforeAction();
    if (settlementExpiry != 0) _warpTo(uint256(settlementExpiry) + 1);
    _afterAction();
  }

  function activate() external {
    _beforeAction();
    BRCNoteVault vault = fixture.systemVault();
    if (vault.state() == BRCState.Funded && block.timestamp < vault.activationDeadline()) {
      vault.activate();
    }
    _afterAction();
  }

  function borrow(uint16 bips) external {
    _beforeAction();
    BRCNoteVault vault = fixture.systemVault();
    WildcatMarket market = fixture.systemMarket();
    if (vault.state() == BRCState.Active && block.timestamp < vault.maturity()) {
      uint256 available = market.borrowableAssets();
      uint256 amount = available * bound(bips, 0, 10_000) / 10_000;
      if (amount != 0) {
        vm.prank(fixture.systemBorrower());
        market.borrow(amount);
      }
    }
    _afterAction();
  }

  function repay(uint16 bips) external {
    _beforeAction();
    BRCNoteVault vault = fixture.systemVault();
    WildcatMarket market = fixture.systemMarket();
    if (vault.state() == BRCState.Active && market.totalDebts() != 0) {
      uint256 amount = market.totalDebts() * bound(bips, 1, 10_000) / 10_000;
      if (amount == 0) amount = 1;
      MockERC20 asset = fixture.systemAsset();
      address borrower = fixture.systemBorrower();
      asset.mint(borrower, amount);
      vm.startPrank(borrower);
      asset.approve(address(market), amount);
      market.repay(amount);
      vm.stopPrank();
    }
    _afterAction();
  }

  function proposeFallback(uint128 price) external {
    _beforeAction();
    BRCNoteVault vault = fixture.systemVault();
    BtcUsdFixingOracle oracle = vault.fixingOracle();
    (,,,,,, bool active) = oracle.fallbackProposal();
    if (
      (vault.state() == BRCState.Active || vault.state() == BRCState.Withdrawing)
        && !oracle.hasMaturityFixing() && !active && block.timestamp >= oracle.fallbackAvailableAt()
    ) {
      address ratifier = oracle.fallbackRatifiers(0);
      uint40 maturity_ = oracle.maturity();
      bytes32 sourceId = oracle.fallbackSourceId();
      vm.prank(ratifier);
      oracle.proposeFallback(
        uint128(bound(price, 1, 200_000e8)),
        maturity_,
        sourceId,
        keccak256(abi.encode(price, block.timestamp))
      );
    }
    _afterAction();
  }

  function approveFallback(bool secondRatifier) external {
    _beforeAction();
    BtcUsdFixingOracle oracle = fixture.systemVault().fixingOracle();
    (uint64 nonce,,,,,, bool active) = oracle.fallbackProposal();
    if (active) {
      uint256 key = secondRatifier ? RATIFIER_TWO_KEY : RATIFIER_ONE_KEY;
      address ratifier = vm.addr(key);
      if (!oracle.fallbackApprovedBy(nonce, ratifier)) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, oracle.fallbackApprovalDigest(nonce));
        oracle.approveFallback(nonce, abi.encodePacked(r, s, v));
      }
    }
    _afterAction();
  }

  function challengeFallback() external {
    _beforeAction();
    BtcUsdFixingOracle oracle = fixture.systemVault().fixingOracle();
    (uint64 nonce,,,,,, bool active) = oracle.fallbackProposal();
    if (active) {
      vm.prank(oracle.fallbackRatifiers(1));
      oracle.challengeFallback(nonce);
    }
    _afterAction();
  }

  function finalizeFallback() external {
    _beforeAction();
    BtcUsdFixingOracle oracle = fixture.systemVault().fixingOracle();
    (uint64 nonce,,, uint40 proposedAt,, uint8 approvals, bool active) = oracle.fallbackProposal();
    if (
      active && approvals >= oracle.fallbackThreshold()
        && block.timestamp >= uint256(proposedAt) + oracle.fallbackChallengePeriod()
    ) {
      oracle.finalizeFallback(nonce);
      fallbackFixings += 1;
    }
    _afterAction();
  }

  function recordPrimaryFixing(uint128 price) external {
    _beforeAction();
    BRCNoteVault vault = fixture.systemVault();
    BRCState current = vault.state();
    BtcUsdFixingOracle oracle = vault.fixingOracle();
    if (
      (current == BRCState.Active || current == BRCState.Withdrawing)
        && block.timestamp >= vault.maturity() && !oracle.hasMaturityFixing()
    ) {
      price = uint128(bound(price, 1, 200_000e8));
      fixture.systemFeed()
        .setRound(2, int256(uint256(price)), vault.maturity(), vault.maturity(), 2);
      oracle.recordMaturityFixing(_round(1, 2), _round(1, 1));
      primaryFixings += 1;
    }
    _afterAction();
  }

  function queueWithdrawal() external {
    _beforeAction();
    BRCNoteVault vault = fixture.systemVault();
    if (vault.state() == BRCState.Active && block.timestamp >= vault.maturity()) {
      settlementExpiry = vault.queueSettlementWithdrawal(new uint32[](0));
    }
    _afterAction();
  }

  function closeMarket() external {
    _beforeAction();
    BRCNoteVault vault = fixture.systemVault();
    WildcatMarket market = fixture.systemMarket();
    if (vault.state() == BRCState.Withdrawing && !market.previousState().isClosed) {
      MockERC20 asset = fixture.systemAsset();
      address borrower = fixture.systemBorrower();
      asset.mint(borrower, uint256(vault.notional()) * 2);
      vm.startPrank(borrower);
      asset.approve(address(market), type(uint256).max);
      market.closeMarket();
      vm.stopPrank();
    }
    _afterAction();
  }

  function executeSettlementWithdrawal() external {
    _beforeAction();
    BRCNoteVault vault = fixture.systemVault();
    if (
      vault.state() == BRCState.Withdrawing && settlementExpiry != 0
        && block.timestamp > settlementExpiry
    ) {
      try vault.executeSettlementWithdrawal(settlementExpiry) returns (uint256) { } catch { }
    }
    _afterAction();
  }

  function finalizeSettlement() external {
    _beforeAction();
    BRCNoteVault vault = fixture.systemVault();
    if (vault.state() == BRCState.Withdrawing && vault.fixingOracle().hasMaturityFixing()) {
      try vault.finalizeSettlement() {
        normalFinalizations += 1;
      } catch { }
    }
    _afterAction();
  }

  function enterRecovery() external {
    _beforeAction();
    BRCNoteVault vault = fixture.systemVault();
    if (
      vault.state() == BRCState.Withdrawing && block.timestamp >= vault.recoveryEligibleAt()
        && fixture.systemMarket().totalSupply() != 0
    ) {
      vault.enterRecovery();
    }
    _afterAction();
  }

  function executeRecoveryWithdrawal() external {
    _beforeAction();
    BRCNoteVault vault = fixture.systemVault();
    if (
      vault.state() == BRCState.Recovery && settlementExpiry != 0
        && block.timestamp > settlementExpiry
    ) {
      try vault.executeRecoveryWithdrawal(settlementExpiry) returns (uint256) { } catch { }
    }
    _afterAction();
  }

  function finalizeRecovery() external {
    _beforeAction();
    BRCNoteVault vault = fixture.systemVault();
    if (
      vault.state() == BRCState.Recovery && block.timestamp >= vault.recoveryWriteOffAt()
        && block.timestamp > settlementExpiry
    ) {
      try vault.finalizeRecovery() {
        recoveryFinalizations += 1;
      } catch { }
    }
    _afterAction();
  }

  function attemptRepeatedWrites() external {
    _beforeAction();
    BRCNoteVault vault = fixture.systemVault();
    if (vault.state() != BRCState.Funded) {
      (bool activationSucceeded,) = address(vault).call(abi.encodeCall(BRCNoteVault.activate, ()));
      if (activationSucceeded) invalidRepeatedWrite = true;
    }
    if (vault.fixingOracle().hasMaturityFixing()) {
      (bool fixingSucceeded,) = address(vault.fixingOracle())
        .call(abi.encodeCall(BtcUsdFixingOracle.recordMaturityFixing, (_round(1, 2), _round(1, 1))));
      if (fixingSucceeded) invalidRepeatedWrite = true;
    }
    if (vault.state() == BRCState.Redeemable || vault.state() == BRCState.Settled) {
      (bool normalSucceeded,) =
        address(vault).call(abi.encodeCall(BRCNoteVault.finalizeSettlement, ()));
      (bool recoverySucceeded,) =
        address(vault).call(abi.encodeCall(BRCNoteVault.finalizeRecovery, ()));
      if (normalSucceeded || recoverySucceeded) invalidRepeatedWrite = true;
    }
    _afterAction();
  }

  function claimBorrowerRebate() external {
    _beforeAction();
    BRCNoteVault vault = fixture.systemVault();
    if (vault.state() == BRCState.Redeemable && !vault.borrowerRebateClaimed()) {
      vault.claimBorrowerRebate();
    }
    _afterAction();
  }

  function transferNotes(uint256 amount, bool toAlice) external {
    _beforeAction();
    BRCNoteVault vault = fixture.systemVault();
    address sender = fixture.systemBorrower();
    address recipient = toAlice ? ALICE : BOB;
    uint256 balance = vault.balanceOf(sender);
    if (balance != 0) {
      amount = bound(amount, 0, balance);
      vm.prank(sender);
      vault.setEligible(recipient, true);
      vm.prank(sender);
      vault.transfer(recipient, amount);
    }
    _afterAction();
  }

  function redeem(uint256 amount, uint8 actorSeed) external {
    _beforeAction();
    BRCNoteVault vault = fixture.systemVault();
    if (vault.state() == BRCState.Redeemable) {
      address actor = _actor(actorSeed);
      uint256 balance = vault.balanceOf(actor);
      if (balance != 0) {
        amount = bound(amount, 1, balance);
        vm.prank(actor);
        observedRedemptions += vault.redeem(amount, actor);
      }
    }
    _afterAction();
  }

  function _beforeAction() internal {
    _syncState();
  }

  function _afterAction() internal {
    _syncState();
  }

  function _syncState() internal {
    BRCNoteVault vault = fixture.systemVault();
    BRCState current = vault.state();
    BtcUsdFixingOracle oracle = vault.fixingOracle();
    if (oracle.hasMaturityFixing()) {
      (
        uint80 roundId,
        address aggregator,
        uint64 aggregatorRoundId,
        uint128 price,
        uint256 updatedAt
      ) = oracle.maturityFixing();
      BtcUsdFixingOracle.MaturityFixing memory fixing =
        BtcUsdFixingOracle.MaturityFixing(roundId, aggregator, aggregatorRoundId, price, updatedAt);
      if (!observedMaturityFixing) {
        observedMaturityFixing = true;
        observedMaturityFixingIsFallback = oracle.maturityFixingIsFallback();
        recordedMaturityFixing = fixing;
      } else if (
        observedMaturityFixingIsFallback != oracle.maturityFixingIsFallback()
          || recordedMaturityFixing.roundId != fixing.roundId
          || recordedMaturityFixing.aggregator != fixing.aggregator
          || recordedMaturityFixing.aggregatorRoundId != fixing.aggregatorRoundId
          || recordedMaturityFixing.price != fixing.price
          || recordedMaturityFixing.updatedAt != fixing.updatedAt
      ) {
        invalidFixingMutation = true;
      }
    }
    if (!initialized) {
      initialized = true;
      previousState = current;
      return;
    }
    if (current == previousState) return;
    bool allowed = (previousState == BRCState.Funded && current == BRCState.Active)
      || (previousState == BRCState.Active && current == BRCState.Withdrawing)
      || (previousState == BRCState.Withdrawing && current == BRCState.Recovery)
      || (previousState == BRCState.Withdrawing && current == BRCState.Redeemable)
      || (previousState == BRCState.Recovery && current == BRCState.Redeemable)
      || (previousState == BRCState.Redeemable && current == BRCState.Settled);
    if (!allowed) invalidTransition = true;
    if (current == BRCState.Settled) terminalSettlements += 1;
    previousState = current;
  }

  function _warpTo(uint256 target) internal {
    if (block.timestamp < target) vm.warp(target);
  }

  function _actor(uint8 seed) internal view returns (address) {
    if (seed % 3 == 0) return fixture.systemBorrower();
    return seed % 3 == 1 ? ALICE : BOB;
  }

  function _round(uint16 phase, uint64 aggregatorRound) internal pure returns (uint80) {
    return (uint80(phase) << 64) | aggregatorRound;
  }
}

contract BRCFundingHandler is Test {
  BRCNoteVault internal immutable vault;
  MockERC20 internal immutable asset;
  uint40 internal immutable deadline;

  address internal constant ALICE = address(0xA11CE);
  address internal constant BOB = address(0xB0B);

  uint256 public subscribedAssets;
  uint256 public refundedAssets;
  bool public invalidTransition;
  BRCState internal previousState = BRCState.Funding;

  constructor(BRCNoteVault vault_, MockERC20 asset_, uint40 deadline_) {
    vault = vault_;
    asset = asset_;
    deadline = deadline_;
  }

  function subscribe(uint128 amount, bool aliceFunds, bool aliceReceives) external {
    if (vault.state() != BRCState.Funding || block.timestamp >= deadline) return;
    uint256 remaining = uint256(vault.notional()) - vault.totalSupply();
    if (remaining == 0) return;
    amount = uint128(bound(amount, 1, remaining));
    address funder = aliceFunds ? ALICE : BOB;
    address recipient = aliceReceives ? ALICE : BOB;
    vm.prank(funder);
    vault.subscribe(amount, recipient);
    subscribedAssets += amount;
  }

  function transferNotes(uint128 amount, bool aliceSends) external {
    address sender = aliceSends ? ALICE : BOB;
    address recipient = aliceSends ? BOB : ALICE;
    uint256 balance = vault.balanceOf(sender);
    if (balance == 0) return;
    amount = uint128(bound(amount, 0, balance));
    vm.prank(sender);
    vault.transfer(recipient, amount);
  }

  function advance(uint32 secondsForward) external {
    vm.warp(block.timestamp + bound(secondsForward, 0, 10 days));
  }

  function resolveFunding() external {
    if (vault.state() != BRCState.Funding) return;
    if (vault.totalSupply() == vault.notional()) {
      vault.finalizeFunding();
    } else if (block.timestamp >= deadline) {
      if (vault.totalSupply() < vault.minimumRaise()) vault.cancelFunding();
      else vault.finalizeFunding();
    }
    _checkTransition();
  }

  function cancelUnactivated() external {
    if (vault.state() == BRCState.Funded) vault.cancelUnactivated();
    _checkTransition();
  }

  function refund(bool aliceRefunds) external {
    if (vault.state() != BRCState.Cancelled) return;
    address investor = aliceRefunds ? ALICE : BOB;
    if (vault.balanceOf(investor) == 0) return;
    vm.prank(investor);
    refundedAssets += vault.refund();
  }

  function _checkTransition() internal {
    BRCState current = vault.state();
    if (current == previousState) return;
    bool allowed = (previousState == BRCState.Funding && current == BRCState.Funded)
      || (previousState == BRCState.Funding && current == BRCState.Cancelled)
      || (previousState == BRCState.Funded && current == BRCState.Cancelled);
    if (!allowed) invalidTransition = true;
    previousState = current;
  }
}

contract BRCFundingInvariantTest is StdInvariant, Test {
  uint128 internal constant NOTIONAL = 1_000_000e6;
  uint128 internal constant MINIMUM_RAISE = 500_000e6;
  address internal constant ALICE = address(0xA11CE);
  address internal constant BOB = address(0xB0B);

  MockERC20 internal asset;
  BRCNoteVault internal vault;
  BRCFundingHandler internal handler;

  function setUp() external {
    vm.warp(10 days);
    uint40 deadline = uint40(block.timestamp + 7 days);
    asset = new MockERC20("USD Coin", "USDC", 6);
    vault = new BRCNoteVault(
      IERC20Metadata(address(asset)),
      address(this),
      "Wildcat BTC BRC Note",
      "wcBRC-BTC",
      NOTIONAL,
      MINIMUM_RAISE,
      deadline,
      true,
      _emptyActivationTerms()
    );
    vault.setEligible(ALICE, true);
    vault.setEligible(BOB, true);
    asset.mint(ALICE, NOTIONAL * 2);
    asset.mint(BOB, NOTIONAL * 2);
    vm.prank(ALICE);
    asset.approve(address(vault), type(uint256).max);
    vm.prank(BOB);
    asset.approve(address(vault), type(uint256).max);
    handler = new BRCFundingHandler(vault, asset, deadline);
    targetContract(address(handler));
  }

  function invariant_fundingAssetsAndClaimsReconcile() external view {
    assertEq(vault.balanceOf(ALICE) + vault.balanceOf(BOB), vault.totalSupply());
    assertEq(handler.subscribedAssets() - handler.refundedAssets(), vault.totalSupply());
    assertEq(asset.balanceOf(address(vault)), vault.totalSupply());
    assertLe(vault.totalSupply(), NOTIONAL);
    assertFalse(handler.invalidTransition());
  }

  function _emptyActivationTerms() internal pure returns (ActivationTerms memory terms) {
    terms.fallbackConfig = BRCFallbackConfig({
      ratifiers: new address[](0),
      threshold: 0,
      waitingPeriod: 0,
      challengePeriod: 0,
      sourceId: bytes32(0)
    });
  }
}

contract BRCSystemInvariantTest is StdInvariant, BRCActivationTest {
  using LibRoleProvider for RoleProvider;

  BRCSystemHandler internal immutable handler;

  constructor() {
    handler = new BRCSystemHandler(IBRCSystemFixture(address(this)));
    targetContract(address(handler));
  }

  function systemVault() external view returns (BRCNoteVault) {
    return vault;
  }

  function systemMarket() external view returns (WildcatMarket) {
    return market;
  }

  function systemAsset() external view returns (MockERC20) {
    return asset;
  }

  function systemFeed() external view returns (MockAggregatorV3) {
    return feed;
  }

  function systemBorrower() external view returns (address) {
    return address(this);
  }

  function testMixedPrimarySettlementReachesTerminalState() external {
    handler.activate();
    handler.advanceToMaturity();
    handler.queueWithdrawal();
    handler.recordPrimaryFixing(80_000e8);
    handler.closeMarket();
    handler.advancePastSettlementExpiry();
    handler.executeSettlementWithdrawal();
    handler.finalizeSettlement();
    handler.redeem(NOTIONAL, 0);
    handler.attemptRepeatedWrites();

    assertEq(handler.primaryFixings(), 1);
    assertEq(handler.normalFinalizations(), 1);
    assertEq(handler.terminalSettlements(), 1);
    assertEq(uint256(vault.state()), uint256(BRCState.Settled));
    assertFalse(handler.invalidRepeatedWrite());
  }

  function testMixedFallbackSettlementReachesTerminalState() external {
    handler.activate();
    handler.advanceToMaturity();
    handler.queueWithdrawal();
    handler.advanceToFallbackAvailable();
    handler.proposeFallback(80_000e8);
    handler.approveFallback(false);
    handler.approveFallback(true);
    handler.advancePastFallbackChallenge();
    handler.finalizeFallback();
    handler.closeMarket();
    handler.advancePastSettlementExpiry();
    handler.executeSettlementWithdrawal();
    handler.finalizeSettlement();
    handler.redeem(NOTIONAL, 0);

    assertEq(handler.fallbackFixings(), 1);
    assertTrue(vault.fixingOracle().maturityFixingIsFallback());
    assertEq(handler.normalFinalizations(), 1);
    assertEq(handler.terminalSettlements(), 1);
    assertEq(uint256(vault.state()), uint256(BRCState.Settled));
  }

  function testMixedRecoveryReachesTerminalState() external {
    handler.activate();
    handler.borrow(10_000);
    handler.advanceToMaturity();
    handler.queueWithdrawal();
    handler.advanceToRecoveryEligible();
    handler.enterRecovery();
    handler.advanceToRecoveryWriteOff();
    handler.finalizeRecovery();
    handler.redeem(NOTIONAL, 0);

    assertEq(handler.recoveryFinalizations(), 1);
    assertEq(vault.borrowerRebate(), 0);
    assertEq(handler.terminalSettlements(), 1);
    assertEq(uint256(vault.state()), uint256(BRCState.Settled));
  }

  function invariant_notesAndClaimsAreConserved() external view {
    uint256 holderNotes = vault.balanceOf(address(this)) + vault.balanceOf(address(0xA11CE))
      + vault.balanceOf(address(0xB0B));
    assertEq(holderNotes, vault.totalSupply());
    assertEq(handler.observedRedemptions(), vault.redeemedAssets());
    assertLe(vault.redeemedAssets(), vault.noteholderReserve());

    BRCState current = vault.state();
    if (current == BRCState.Redeemable || current == BRCState.Settled) {
      assertEq(uint256(vault.noteholderReserve()) + vault.borrowerRebate(), vault.wildcatProceeds());
      uint256 unpaidRebate = vault.borrowerRebateClaimed() ? 0 : vault.borrowerRebate();
      uint256 unredeemed = uint256(vault.noteholderReserve()) - vault.redeemedAssets();
      assertGe(asset.balanceOf(address(vault)), unredeemed + unpaidRebate);
    }
    if (current == BRCState.Settled) {
      assertEq(vault.totalSupply(), 0);
      assertEq(vault.redeemedAssets(), vault.noteholderReserve());
      assertTrue(vault.borrowerRebateClaimed());
    }
  }

  function invariant_rebateRequiresCompletePerformance() external view {
    if (vault.borrowerRebate() != 0) {
      assertTrue(vault.fixingOracle().hasMaturityFixing());
      assertEq(market.totalSupply(), 0);
      assertTrue(vault.state() == BRCState.Redeemable || vault.state() == BRCState.Settled);
    }
  }

  function invariant_initialFixingAndLifecycleAreImmutable() external view {
    (uint80 roundId, uint128 price, uint256 updatedAt) = vault.fixingOracle().initialFixing();
    assertEq(roundId, (uint80(1) << 64) | 1);
    assertEq(price, 100_000e8);
    assertEq(updatedAt, 10 days);
    assertFalse(handler.invalidTransition());
    assertFalse(handler.invalidFixingMutation());
    assertFalse(handler.invalidRepeatedWrite());
  }

  function invariant_singletonLenderPolicyRemainsSealed() external view {
    assertTrue(hooks.roleProviderConfigurationSealed());
    RoleProvider[] memory providers = hooks.getPullProviders();
    assertEq(providers.length, 1);
    assertEq(providers[0].timeToLive(), 0);
    assertEq(ISingletonRoleProvider(providers[0].providerAddress()).lender(), address(vault));
    assertEq(hooks.getPushProviders().length, 0);
  }
}

contract BRCSystemMathHarness {
  using BRCMath for BRCSeriesTerms;

  function slash(BRCSeriesTerms memory terms, uint128 price) external pure returns (uint128) {
    return terms.principalSlash(price);
  }
}

contract BRCSystemPayoffDifferentialTest is Test {
  BRCSystemMathHarness internal immutable harness = new BRCSystemMathHarness();

  /// @dev Independent exact-rational oracle: q=floor(n/d) iff q*d <= n < (q+1)*d.
  function testFuzzPayoffMatchesExactRationalBounds(
    uint128 notional,
    uint128 strike,
    uint128 barrier,
    uint128 maturityPrice
  ) external view {
    notional = uint128(bound(notional, 1, type(uint128).max));
    strike = uint128(bound(strike, 1, type(uint128).max));
    barrier = uint128(bound(barrier, 0, strike));
    BRCSeriesTerms memory terms = BRCSeriesTerms({
      notional: notional, strike: strike, barrier: barrier, maturity: 1, settlementAssetDecimals: 18
    });

    uint256 actual = harness.slash(terms, maturityPrice);
    if (maturityPrice > barrier || maturityPrice >= strike) {
      assertEq(actual, 0);
      return;
    }

    uint256 numerator = uint256(notional) * (uint256(strike) - maturityPrice);
    assertLe(actual * strike, numerator);
    assertGt((actual + 1) * strike, numerator);
    assertLe(actual, notional);
  }
}
