// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { ActivationTerms, BRCNoteVault } from "../src/BRCNoteVault.sol";
import { BRCState } from "../src/BRCSeries.sol";
import { IERC20Metadata } from "../src/interfaces/IERC20.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

contract BRCNoteVaultTest is Test {
  uint128 internal constant NOTIONAL = 1_000_000e6;
  uint128 internal constant MINIMUM_RAISE = 500_000e6;

  address internal alice = address(0xA11CE);
  address internal bob = address(0xB0B);
  address internal operator = address(0x0F);

  MockERC20 internal asset;
  BRCNoteVault internal vault;
  uint40 internal deadline;

  function setUp() external {
    vm.warp(10 days);
    deadline = uint40(block.timestamp + 7 days);
    asset = new MockERC20("USD Coin", "USDC", 6);
    vault = _deploy(asset, true);

    vault.setEligible(alice, true);
    vault.setEligible(bob, true);
    vault.setEligible(operator, true);
    asset.mint(alice, NOTIONAL);
    asset.mint(bob, NOTIONAL);
    vm.prank(alice);
    asset.approve(address(vault), type(uint256).max);
    vm.prank(bob);
    asset.approve(address(vault), type(uint256).max);
  }

  function testPartialAndExactCapSubscriptions() external {
    _subscribe(alice, 400_000e6, alice);
    _subscribe(bob, 600_000e6, bob);

    assertEq(vault.totalSupply(), NOTIONAL);
    assertEq(asset.balanceOf(address(vault)), NOTIONAL);
    assertEq(vault.balanceOf(alice), 400_000e6);
    assertEq(vault.balanceOf(bob), 600_000e6);

    vm.expectRevert(BRCNoteVault.FundingClosed.selector);
    _subscribe(alice, 1, alice);
  }

  function testRejectsOverCapAndDeadlineSubscriptions() external {
    _subscribe(alice, 900_000e6, alice);
    vm.expectRevert(BRCNoteVault.HardCapExceeded.selector);
    _subscribe(bob, 100_000e6 + 1, bob);

    vm.warp(deadline);
    vm.expectRevert(BRCNoteVault.FundingClosed.selector);
    _subscribe(bob, 1, bob);
  }

  function testFinalizesAtCapOrAfterDeadline() external {
    _subscribe(alice, NOTIONAL, alice);
    vault.finalizeFunding();
    assertEq(uint256(vault.state()), uint256(BRCState.Funded));

    BRCNoteVault second = _deploy(asset, false);
    asset.mint(alice, MINIMUM_RAISE);
    vm.prank(alice);
    asset.approve(address(second), type(uint256).max);
    vm.prank(alice);
    second.subscribe(MINIMUM_RAISE, alice);
    vm.expectRevert(BRCNoteVault.FundingStillOpen.selector);
    second.finalizeFunding();
    vm.warp(deadline);
    second.finalizeFunding();
    assertEq(uint256(second.state()), uint256(BRCState.Funded));
  }

  function testUnconfiguredSuccessfulRaiseCanCancelAndRefund() external {
    _subscribe(alice, NOTIONAL, alice);
    vault.finalizeFunding();
    vault.cancelUnactivated();

    vm.prank(alice);
    vault.refund();
    assertEq(uint256(vault.state()), uint256(BRCState.Cancelled));
    assertEq(vault.totalSupply(), 0);
    assertEq(asset.balanceOf(address(vault)), 0);
  }

  function testCancelsUnderfundedRaiseAndRefundsCurrentHolders() external {
    _subscribe(alice, 200_000e6, alice);
    _subscribe(bob, 100_000e6, bob);
    vm.prank(alice);
    vault.transfer(bob, 50_000e6);

    vm.warp(deadline);
    vault.cancelFunding();
    assertEq(uint256(vault.state()), uint256(BRCState.Cancelled));

    uint256 bobBefore = asset.balanceOf(bob);
    vm.prank(bob);
    vault.refund();
    assertEq(asset.balanceOf(bob) - bobBefore, 150_000e6);
    assertEq(vault.totalSupply(), 150_000e6);

    uint256 aliceBefore = asset.balanceOf(alice);
    vm.prank(alice);
    vault.refund();
    assertEq(asset.balanceOf(alice) - aliceBefore, 150_000e6);
    assertEq(vault.totalSupply(), 0);
    assertEq(asset.balanceOf(address(vault)), 0);

    vm.prank(alice);
    vm.expectRevert(BRCNoteVault.ZeroAmount.selector);
    vault.refund();
  }

  function testRejectsWrongFinalizationAndRepeatedTransitions() external {
    _subscribe(alice, MINIMUM_RAISE, alice);
    vm.warp(deadline);
    vm.expectRevert(BRCNoteVault.RaiseSucceeded.selector);
    vault.cancelFunding();
    vault.finalizeFunding();

    vm.expectRevert(BRCNoteVault.WrongState.selector);
    vault.finalizeFunding();
    vm.expectRevert(BRCNoteVault.WrongState.selector);
    vault.cancelFunding();
  }

  function testRestrictedTransfersCheckSenderRecipientAndOperator() external {
    _subscribe(alice, 100e6, alice);

    vault.setEligible(bob, false);
    vm.prank(alice);
    vm.expectRevert(abi.encodeWithSelector(BRCNoteVault.IneligibleAccount.selector, bob));
    vault.transfer(bob, 1);

    vault.setEligible(bob, true);
    vm.prank(alice);
    vault.approve(operator, 50e6);
    vault.setEligible(operator, false);
    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(BRCNoteVault.IneligibleAccount.selector, operator));
    vault.transferFrom(alice, bob, 1);

    vault.setEligible(operator, true);
    vault.setEligible(alice, false);
    vm.prank(operator);
    vm.expectRevert(abi.encodeWithSelector(BRCNoteVault.IneligibleAccount.selector, alice));
    vault.transferFrom(alice, bob, 1);
  }

  function testCanRevokeAllowanceWhileOperatorIsIneligible() external {
    _subscribe(alice, 100e6, alice);
    vm.prank(alice);
    vault.approve(operator, 100e6);

    vault.setEligible(operator, false);
    vm.prank(alice);
    vault.approve(operator, 0);
    vault.setEligible(operator, true);

    vm.prank(operator);
    vm.expectRevert(BRCNoteVault.InsufficientAllowance.selector);
    vault.transferFrom(alice, bob, 1);
  }

  function testUnrestrictedVaultAllowsOpenTransfers() external {
    BRCNoteVault openVault = _deploy(asset, false);
    vm.prank(alice);
    asset.approve(address(openVault), 10e6);
    vm.prank(alice);
    openVault.subscribe(10e6, alice);
    vm.prank(alice);
    openVault.transfer(address(0xCAFE), 10e6);
    assertEq(openVault.balanceOf(address(0xCAFE)), 10e6);
  }

  function testAcceptsNoReturnTokenAndRejectsFalseOrFeeTransfers() external {
    asset.setNoReturnData(true);
    _subscribe(alice, 10e6, alice);
    assertEq(vault.balanceOf(alice), 10e6);

    asset.setNoReturnData(false);
    asset.setFailTransfers(true);
    vm.expectRevert(BRCNoteVault.TransferFailed.selector);
    _subscribe(bob, 10e6, bob);

    asset.setFailTransfers(false);
    asset.setFeeBips(100);
    vm.expectRevert(BRCNoteVault.AssetBalanceMismatch.selector);
    _subscribe(bob, 10e6, bob);
  }

  function testDetectsRebaseBeforeNextStateChange() external {
    _subscribe(alice, MINIMUM_RAISE, alice);
    asset.rebase(address(vault), -int256(1));
    vm.warp(deadline);

    vm.expectRevert(BRCNoteVault.AssetBalanceMismatch.selector);
    vault.finalizeFunding();
  }

  function testUnsolicitedSurplusCannotBlockFundingOrRefunds() external {
    _subscribe(alice, 200_000e6, alice);
    vm.prank(bob);
    assertTrue(asset.transfer(address(vault), 1));

    _subscribe(bob, 100_000e6, bob);
    vm.warp(deadline);
    vault.cancelFunding();

    vm.prank(alice);
    vault.refund();
    vm.prank(bob);
    vault.refund();

    assertEq(vault.totalSupply(), 0);
    assertEq(asset.balanceOf(address(vault)), 1);
  }

  function testUnsolicitedSurplusCannotBlockFinalization() external {
    _subscribe(alice, NOTIONAL, alice);
    vm.prank(bob);
    assertTrue(asset.transfer(address(vault), 1));

    vault.finalizeFunding();
    assertEq(uint256(vault.state()), uint256(BRCState.Funded));
  }

  function testRefundDoesNotDependOnCurrentEligibility() external {
    _subscribe(alice, 10e6, alice);
    vm.warp(deadline);
    vault.cancelFunding();
    vault.setEligible(alice, false);

    vm.prank(alice);
    vault.refund();
    assertEq(vault.balanceOf(alice), 0);
  }

  function testRejectsFeeChargingRefund() external {
    _subscribe(alice, 10e6, alice);
    vm.warp(deadline);
    vault.cancelFunding();
    asset.setFeeBips(100);

    vm.prank(alice);
    vm.expectRevert(BRCNoteVault.AssetBalanceMismatch.selector);
    vault.refund();

    assertEq(vault.balanceOf(alice), 10e6);
    assertEq(vault.totalSupply(), 10e6);
  }

  function _subscribe(address payer, uint256 amount, address recipient) internal {
    vm.prank(payer);
    vault.subscribe(amount, recipient);
  }

  function _deploy(MockERC20 token, bool restricted) internal returns (BRCNoteVault) {
    return new BRCNoteVault(
      IERC20Metadata(address(token)),
      address(this),
      "Wildcat BTC BRC Note",
      "wcBRC-BTC",
      NOTIONAL,
      MINIMUM_RAISE,
      deadline,
      restricted,
      ActivationTerms({
        market: address(0),
        borrower: address(0),
        borrowerPrincipal: address(0),
        hooksFactory: address(0),
        hooksTemplate: address(0),
        providerFactory: address(0),
        providerFactoryCodeHash: bytes32(0),
        marketSalt: bytes32(0),
        providerSalt: bytes32(0),
        annualInterestBips: 0,
        reserveRatioBips: 0,
        delinquencyFeeBips: 0,
        delinquencyGracePeriod: 0,
        withdrawalBatchDuration: 0,
        feeRecipient: address(0),
        protocolFeeBips: 0,
        activationDeadline: 0,
        maturity: 0,
        btcUsdFeed: address(0),
        feedDecimals: 0,
        feedDescriptionHash: bytes32(0),
        maxInitialAge: 0,
        maxFutureSkew: 0,
        barrierBips: 0,
        maxObservationDelay: 0
      })
    );
  }
}
