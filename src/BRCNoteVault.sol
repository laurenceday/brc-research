// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { BRCState } from "./BRCSeries.sol";
import { BRCSeriesTerms } from "./BRCSeries.sol";
import { BRCMath } from "./BRCMath.sol";
import { BRCFallbackConfig } from "./BRCFallback.sol";
import { BtcUsdFixingOracle } from "./BtcUsdFixingOracle.sol";
import { AggregatorV3Interface } from "./interfaces/AggregatorV3Interface.sol";
import { IERC20, IERC20Metadata } from "./interfaces/IERC20.sol";
import { FixedTermHooks, HookedMarket } from "v2-protocol/access/FixedTermHooks.sol";
import {
  ISingletonRoleProviderFactory,
  SingletonRoleProviderFactoryInputs
} from "v2-protocol/providers/ISingletonRoleProviderFactory.sol";
import { ISingletonRoleProvider } from "v2-protocol/providers/ISingletonRoleProvider.sol";
import { HooksConfig, LibHooksConfig } from "v2-protocol/types/HooksConfig.sol";
import { MarketState } from "v2-protocol/libraries/MarketState.sol";
import { AccountWithdrawalStatus, WithdrawalBatch } from "v2-protocol/libraries/Withdrawal.sol";
import { RoleProvider, LibRoleProvider } from "v2-protocol/types/RoleProvider.sol";

using LibHooksConfig for HooksConfig;
using LibRoleProvider for RoleProvider;

struct ActivationTerms {
  address market;
  address borrower;
  address borrowerPrincipal;
  address hooksFactory;
  address hooksTemplate;
  address providerFactory;
  bytes32 providerFactoryCodeHash;
  bytes32 marketSalt;
  bytes32 providerSalt;
  uint16 annualInterestBips;
  uint16 reserveRatioBips;
  uint16 delinquencyFeeBips;
  uint32 delinquencyGracePeriod;
  uint32 withdrawalBatchDuration;
  address feeRecipient;
  uint16 protocolFeeBips;
  uint40 activationDeadline;
  uint40 maturity;
  address btcUsdFeed;
  uint8 feedDecimals;
  bytes32 feedDescriptionHash;
  uint32 maxInitialAge;
  uint32 maxFutureSkew;
  uint16 barrierBips;
  uint32 maxObservationDelay;
  uint32 recoveryDelay;
  uint32 writeOffDelay;
  BRCFallbackConfig fallbackConfig;
}

interface IHooksFactoryView {
  function computeMarketAddress(bytes32 salt) external view returns (address);

  function getHooksTemplateForInstance(address hooks) external view returns (address);
}

interface IWildcatActivationMarket {
  function asset() external view returns (address);

  function borrower() external view returns (address);

  function borrowerPrincipal() external view returns (address);

  function pendingBorrower() external view returns (address);

  function factory() external view returns (address);

  function hooks() external view returns (HooksConfig);

  function maxTotalSupply() external view returns (uint256);

  function annualInterestBips() external view returns (uint256);

  function reserveRatioBips() external view returns (uint256);

  function delinquencyFeeBips() external view returns (uint256);

  function delinquencyGracePeriod() external view returns (uint256);

  function withdrawalBatchDuration() external view returns (uint256);

  function feeRecipient() external view returns (address);

  function previousState() external view returns (MarketState memory);

  function totalSupply() external view returns (uint256);

  function balanceOf(address account) external view returns (uint256);

  function scaledBalanceOf(address account) external view returns (uint256);

  function scaleFactor() external view returns (uint256);

  function deposit(uint256 amount) external;

  function queueFullWithdrawal() external returns (uint32 expiry);

  function executeWithdrawal(address account, uint32 expiry) external returns (uint256 amount);

  function getWithdrawalBatch(uint32 expiry) external view returns (WithdrawalBatch memory);

  function getAccountWithdrawalStatus(address account, uint32 expiry)
    external
    view
    returns (AccountWithdrawalStatus memory);
}

contract BRCNoteVault {
  error ZeroAddress();
  error InvalidTerms();
  error WrongState();
  error FundingClosed();
  error FundingStillOpen();
  error RaiseSucceeded();
  error RaiseFailed();
  error ZeroAmount();
  error HardCapExceeded();
  error TransferFailed();
  error AssetBalanceMismatch();
  error InsufficientBalance();
  error InsufficientAllowance();
  error NotAccessController();
  error IneligibleAccount(address account);
  error ReentrantCall();
  error ActivationNotConfigured();
  error ActivationPolicyMismatch();
  error IncompleteRaise();
  error ActivationWindowClosed();
  error ActivationStillOpen();
  error MaturityFixingMissing();
  error MaturityNotReached();
  error SettlementQueueWindowClosed();
  error WithdrawalNotReady();
  error IncompleteMarketPerformance();
  error RebateAlreadyClaimed();
  error RecoveryNotReady();
  error MarketPerformanceComplete();

  string public name;
  string public symbol;
  uint8 public immutable decimals;

  IERC20 public immutable settlementAsset;
  address public immutable accessController;
  uint128 public immutable notional;
  uint128 public immutable minimumRaise;
  uint40 public immutable fundingDeadline;
  bool public immutable transfersRestricted;
  address public immutable expectedMarket;
  address public immutable expectedBorrower;
  address public immutable expectedBorrowerPrincipal;
  address public immutable expectedHooksFactory;
  address public immutable expectedHooksTemplate;
  address public immutable expectedProviderFactory;
  bytes32 public immutable expectedProviderFactoryCodeHash;
  bytes32 public immutable expectedMarketSalt;
  bytes32 public immutable expectedProviderSalt;
  uint16 public immutable expectedAnnualInterestBips;
  uint16 public immutable expectedReserveRatioBips;
  uint16 public immutable expectedDelinquencyFeeBips;
  uint32 public immutable expectedDelinquencyGracePeriod;
  uint32 public immutable expectedWithdrawalBatchDuration;
  address public immutable expectedFeeRecipient;
  uint16 public immutable expectedProtocolFeeBips;
  uint40 public immutable activationDeadline;
  uint40 public immutable maturity;
  uint40 public immutable recoveryEligibleAt;
  uint40 public immutable recoveryWriteOffAt;
  BtcUsdFixingOracle public immutable fixingOracle;

  BRCState public state;
  uint256 public totalSupply;
  uint104 public activatedScaledAmount;
  uint32[] public settlementBatchExpiries;
  mapping(uint32 => bool) public isSettlementBatch;
  uint128 public wildcatProceeds;
  uint128 public borrowerRebate;
  uint128 public noteholderReserve;
  uint128 public redeemedAssets;
  uint256 public settlementBaselineBalance;
  bool public borrowerRebateClaimed;
  bool private locked;

  mapping(address => uint256) public balanceOf;
  mapping(address => mapping(address => uint256)) public allowance;
  mapping(address => bool) public isEligible;

  event Transfer(address indexed sender, address indexed recipient, uint256 amount);
  event Approval(address indexed owner, address indexed spender, uint256 amount);
  event EligibilitySet(address indexed account, bool eligible);
  event Subscribed(
    address indexed payer, address indexed recipient, uint256 amount, uint256 totalNotes
  );
  event FundingFinalized(uint256 totalNotes);
  event FundingCancelled(uint256 totalNotes);
  event Refunded(address indexed account, uint256 amount, uint256 totalNotes);
  event Activated(
    address indexed market,
    address indexed hooks,
    address indexed provider,
    address fixingOracle,
    uint80 fixingRoundId,
    uint128 fixingPrice,
    uint256 fixingUpdatedAt,
    uint256 depositedAmount
  );
  event SettlementWithdrawalQueued(uint32 indexed expiry, uint104 scaledAmount, bool adopted);
  event SettlementWithdrawalExecuted(uint32 indexed expiry, uint256 amount);
  event SettlementFinalized(
    uint128 wildcatProceeds,
    uint128 borrowerRebate,
    uint128 noteholderReserve,
    uint128 maturityPrice
  );
  event RecoveryEntered(uint40 eligibleAt, uint40 writeOffAt);
  event RecoveryFinalized(uint128 recoveredAssets, uint256 outstandingNotes);
  event BorrowerRebateClaimed(address indexed recipient, uint256 amount);
  event Redeemed(
    address indexed owner,
    address indexed recipient,
    uint256 noteAmount,
    uint256 assetAmount,
    uint256 remainingNotes
  );

  modifier nonReentrant() {
    if (locked) revert ReentrantCall();
    locked = true;
    _;
    locked = false;
  }

  constructor(
    IERC20Metadata settlementAsset_,
    address accessController_,
    string memory name_,
    string memory symbol_,
    uint128 notional_,
    uint128 minimumRaise_,
    uint40 fundingDeadline_,
    bool transfersRestricted_,
    ActivationTerms memory activationTerms_
  ) {
    if (address(settlementAsset_) == address(0) || accessController_ == address(0)) {
      revert ZeroAddress();
    }
    uint8 assetDecimals = settlementAsset_.decimals();
    if (
      notional_ == 0 || minimumRaise_ == 0 || minimumRaise_ > notional_
        || fundingDeadline_ <= block.timestamp || assetDecimals > 18
    ) revert InvalidTerms();

    settlementAsset = settlementAsset_;
    accessController = accessController_;
    name = name_;
    symbol = symbol_;
    decimals = assetDecimals;
    notional = notional_;
    minimumRaise = minimumRaise_;
    fundingDeadline = fundingDeadline_;
    transfersRestricted = transfersRestricted_;

    expectedMarket = activationTerms_.market;
    expectedBorrower = activationTerms_.borrower;
    expectedBorrowerPrincipal = activationTerms_.borrowerPrincipal;
    expectedHooksFactory = activationTerms_.hooksFactory;
    expectedHooksTemplate = activationTerms_.hooksTemplate;
    expectedProviderFactory = activationTerms_.providerFactory;
    expectedProviderFactoryCodeHash = activationTerms_.providerFactoryCodeHash;
    expectedMarketSalt = activationTerms_.marketSalt;
    expectedProviderSalt = activationTerms_.providerSalt;
    expectedAnnualInterestBips = activationTerms_.annualInterestBips;
    expectedReserveRatioBips = activationTerms_.reserveRatioBips;
    expectedDelinquencyFeeBips = activationTerms_.delinquencyFeeBips;
    expectedDelinquencyGracePeriod = activationTerms_.delinquencyGracePeriod;
    expectedWithdrawalBatchDuration = activationTerms_.withdrawalBatchDuration;
    expectedFeeRecipient = activationTerms_.feeRecipient;
    expectedProtocolFeeBips = activationTerms_.protocolFeeBips;
    activationDeadline = activationTerms_.activationDeadline;
    maturity = activationTerms_.maturity;

    if (activationTerms_.market == address(0)) {
      recoveryEligibleAt = 0;
      recoveryWriteOffAt = 0;
      fixingOracle = BtcUsdFixingOracle(address(0));
    } else {
      uint256 recoveryEligibleAt_ =
        uint256(activationTerms_.maturity) + activationTerms_.recoveryDelay;
      uint256 recoveryWriteOffAt_ = recoveryEligibleAt_ + activationTerms_.writeOffDelay;
      if (
        minimumRaise_ != notional_ || notional_ > type(uint104).max
          || activationTerms_.borrower == address(0)
          || activationTerms_.borrowerPrincipal == address(0)
          || activationTerms_.hooksFactory == address(0)
          || activationTerms_.hooksTemplate == address(0)
          || activationTerms_.providerFactory == address(0)
          || activationTerms_.providerFactoryCodeHash == bytes32(0)
          || activationTerms_.btcUsdFeed == address(0)
          || address(bytes20(activationTerms_.marketSalt)) != activationTerms_.borrower
          || activationTerms_.activationDeadline <= fundingDeadline_
          || activationTerms_.maturity <= activationTerms_.activationDeadline
          || activationTerms_.recoveryDelay < activationTerms_.maxObservationDelay
          || activationTerms_.writeOffDelay == 0
          || recoveryEligibleAt_ + activationTerms_.withdrawalBatchDuration + 1 > type(uint32).max
          || recoveryWriteOffAt_ > type(uint40).max
          || uint256(activationTerms_.maturity) + activationTerms_.maxObservationDelay
              + activationTerms_.withdrawalBatchDuration + 1 > type(uint32).max
          || IHooksFactoryView(activationTerms_.hooksFactory)
              .computeMarketAddress(activationTerms_.marketSalt) != activationTerms_.market
      ) revert InvalidTerms();

      recoveryEligibleAt = uint40(recoveryEligibleAt_);
      recoveryWriteOffAt = uint40(recoveryWriteOffAt_);

      fixingOracle = new BtcUsdFixingOracle(
        AggregatorV3Interface(activationTerms_.btcUsdFeed),
        address(this),
        activationTerms_.feedDecimals,
        activationTerms_.feedDescriptionHash,
        activationTerms_.maxInitialAge,
        activationTerms_.maxFutureSkew,
        activationTerms_.barrierBips,
        activationTerms_.maturity,
        activationTerms_.maxObservationDelay,
        activationTerms_.fallbackConfig
      );
      fixingOracle.recordInitialFixing();
    }
  }

  function activate() external nonReentrant {
    if (expectedMarket == address(0)) revert ActivationNotConfigured();
    if (state != BRCState.Funded) revert WrongState();
    if (block.timestamp >= activationDeadline) revert ActivationWindowClosed();
    if (totalSupply != notional) revert IncompleteRaise();

    (IWildcatActivationMarket market, FixedTermHooks hooks, address provider) =
      _validateActivationPolicy();
    (uint80 fixingRoundId, uint128 fixingPrice, uint256 fixingUpdatedAt) =
      fixingOracle.initialFixing();

    uint256 assetBalanceBefore = settlementAsset.balanceOf(address(this));
    uint256 marketAssetBalanceBefore = settlementAsset.balanceOf(expectedMarket);
    uint256 marketBalanceBefore = market.balanceOf(address(this));
    uint256 scaledMarketBalanceBefore = market.scaledBalanceOf(address(this));
    if (
      assetBalanceBefore < notional || marketBalanceBefore != 0 || scaledMarketBalanceBefore != 0
        || market.totalSupply() != 0
    ) {
      revert ActivationPolicyMismatch();
    }

    _safeApprove(address(settlementAsset), expectedMarket, 0);
    _safeApprove(address(settlementAsset), expectedMarket, notional);
    market.deposit(notional);
    _safeApprove(address(settlementAsset), expectedMarket, 0);

    uint256 expectedScaledAmount = uint256(notional) * 1e27 / market.scaleFactor();
    if (
      settlementAsset.balanceOf(address(this)) != assetBalanceBefore - notional
        || settlementAsset.balanceOf(expectedMarket) != marketAssetBalanceBefore + notional
        || market.scaledBalanceOf(address(this)) != scaledMarketBalanceBefore + expectedScaledAmount
        || settlementAsset.allowance(address(this), expectedMarket) != 0
    ) revert AssetBalanceMismatch();

    activatedScaledAmount = uint104(expectedScaledAmount);
    settlementBaselineBalance = settlementAsset.balanceOf(address(this));
    state = BRCState.Active;
    emit Activated(
      expectedMarket,
      address(hooks),
      provider,
      address(fixingOracle),
      fixingRoundId,
      fixingPrice,
      fixingUpdatedAt,
      notional
    );
  }

  function cancelUnactivated() external {
    if (state != BRCState.Funded) revert WrongState();
    if (expectedMarket != address(0) && block.timestamp < activationDeadline) {
      revert ActivationStillOpen();
    }
    if (settlementAsset.balanceOf(address(this)) < totalSupply) revert AssetBalanceMismatch();

    state = BRCState.Cancelled;
    emit FundingCancelled(totalSupply);
  }

  function queueSettlementWithdrawal(uint32[] calldata preexistingExpiries)
    external
    nonReentrant
    returns (uint32 expiry)
  {
    if (state != BRCState.Active) revert WrongState();
    if (block.timestamp < maturity) revert MaturityNotReached();
    expiry = _queueCompletePosition(preexistingExpiries);
    state = BRCState.Withdrawing;
  }

  function executeSettlementWithdrawal(uint32 expiry)
    external
    nonReentrant
    returns (uint256 amount)
  {
    if (state != BRCState.Withdrawing) revert WrongState();
    amount = _executeSettlementBatch(expiry);
  }

  function enterRecovery() external {
    if (state != BRCState.Withdrawing) revert WrongState();
    if (block.timestamp < recoveryEligibleAt) revert RecoveryNotReady();
    if (IWildcatActivationMarket(expectedMarket).totalSupply() == 0) {
      revert MarketPerformanceComplete();
    }

    state = BRCState.Recovery;
    emit RecoveryEntered(recoveryEligibleAt, recoveryWriteOffAt);
  }

  function executeRecoveryWithdrawal(uint32 expiry) external nonReentrant returns (uint256 amount) {
    if (state != BRCState.Recovery) revert WrongState();
    amount = _executeSettlementBatch(expiry);
  }

  function finalizeRecovery() external nonReentrant {
    if (state != BRCState.Recovery) revert WrongState();
    if (block.timestamp < recoveryWriteOffAt) revert RecoveryNotReady();

    IWildcatActivationMarket market = IWildcatActivationMarket(expectedMarket);
    uint256 totalScaled;
    uint256 totalRecovered;
    uint256 batchCount = settlementBatchExpiries.length;
    if (batchCount == 0) revert IncompleteMarketPerformance();
    for (uint256 i; i < batchCount; i++) {
      uint32 expiry = settlementBatchExpiries[i];
      WithdrawalBatch memory batch = market.getWithdrawalBatch(expiry);
      AccountWithdrawalStatus memory status =
        market.getAccountWithdrawalStatus(address(this), expiry);
      if (batch.scaledTotalAmount == 0 || status.scaledAmount != batch.scaledTotalAmount) {
        revert IncompleteMarketPerformance();
      }
      if (expiry >= block.timestamp) revert WithdrawalNotReady();
      if (status.normalizedAmountWithdrawn != batch.normalizedAmountPaid) {
        _executeSettlementBatch(expiry);
        status = market.getAccountWithdrawalStatus(address(this), expiry);
      }
      totalScaled += status.scaledAmount;
      totalRecovered += status.normalizedAmountWithdrawn;
    }
    if (totalScaled != activatedScaledAmount || totalRecovered > type(uint128).max) {
      revert IncompleteMarketPerformance();
    }

    uint128 recovered = uint128(totalRecovered);
    if (settlementAsset.balanceOf(address(this)) < settlementBaselineBalance + recovered) {
      revert IncompleteMarketPerformance();
    }

    wildcatProceeds = recovered;
    noteholderReserve = recovered;
    borrowerRebateClaimed = true;
    state = BRCState.Redeemable;
    emit RecoveryFinalized(recovered, totalSupply);
  }

  function _executeSettlementBatch(uint32 expiry) internal returns (uint256 amount) {
    if (!isSettlementBatch[expiry]) revert IncompleteMarketPerformance();
    IWildcatActivationMarket market = IWildcatActivationMarket(expectedMarket);
    WithdrawalBatch memory batch = market.getWithdrawalBatch(expiry);
    AccountWithdrawalStatus memory status = market.getAccountWithdrawalStatus(address(this), expiry);
    if (
      status.scaledAmount != batch.scaledTotalAmount
        || status.normalizedAmountWithdrawn == batch.normalizedAmountPaid
    ) revert WithdrawalNotReady();

    uint256 balanceBefore = settlementAsset.balanceOf(address(this));
    amount = market.executeWithdrawal(address(this), expiry);
    if (settlementAsset.balanceOf(address(this)) != balanceBefore + amount) {
      revert AssetBalanceMismatch();
    }
    emit SettlementWithdrawalExecuted(expiry, amount);
  }

  function finalizeSettlement() external {
    if (state != BRCState.Withdrawing) revert WrongState();
    if (!fixingOracle.hasMaturityFixing()) revert MaturityFixingMissing();
    IWildcatActivationMarket market = IWildcatActivationMarket(expectedMarket);
    if (market.totalSupply() != 0) revert IncompleteMarketPerformance();

    uint256 totalScaled;
    uint256 totalProceeds;
    uint256 batchCount = settlementBatchExpiries.length;
    if (batchCount == 0) revert IncompleteMarketPerformance();
    for (uint256 i; i < batchCount; i++) {
      uint32 expiry = settlementBatchExpiries[i];
      WithdrawalBatch memory batch = market.getWithdrawalBatch(expiry);
      AccountWithdrawalStatus memory status =
        market.getAccountWithdrawalStatus(address(this), expiry);
      if (
        batch.scaledTotalAmount == 0 || batch.scaledAmountBurned != batch.scaledTotalAmount
          || status.scaledAmount != batch.scaledTotalAmount
          || status.normalizedAmountWithdrawn != batch.normalizedAmountPaid
      ) revert IncompleteMarketPerformance();
      totalScaled += status.scaledAmount;
      totalProceeds += status.normalizedAmountWithdrawn;
    }
    if (totalScaled != activatedScaledAmount || totalProceeds > type(uint128).max) {
      revert IncompleteMarketPerformance();
    }

    uint128 proceeds = uint128(totalProceeds);
    if (settlementAsset.balanceOf(address(this)) < settlementBaselineBalance + proceeds) {
      revert IncompleteMarketPerformance();
    }

    (,,, uint128 maturityPrice,) = fixingOracle.maturityFixing();
    BRCSeriesTerms memory terms = BRCSeriesTerms({
      notional: notional,
      strike: fixingOracle.strike(),
      barrier: fixingOracle.barrier(),
      maturity: maturity,
      settlementAssetDecimals: decimals
    });
    uint128 rebate = BRCMath.principalSlash(terms, maturityPrice);
    if (rebate > proceeds) revert IncompleteMarketPerformance();

    wildcatProceeds = proceeds;
    borrowerRebate = rebate;
    noteholderReserve = BRCMath.noteholderPool(proceeds, rebate);
    borrowerRebateClaimed = rebate == 0;
    state = BRCState.Redeemable;
    emit SettlementFinalized(proceeds, rebate, noteholderReserve, maturityPrice);
  }

  function claimBorrowerRebate() external nonReentrant returns (uint256 amount) {
    if (state != BRCState.Redeemable) revert WrongState();
    if (borrowerRebateClaimed) revert RebateAlreadyClaimed();
    borrowerRebateClaimed = true;
    amount = borrowerRebate;

    uint256 vaultBalanceBefore = settlementAsset.balanceOf(address(this));
    uint256 recipientBalanceBefore = settlementAsset.balanceOf(expectedBorrowerPrincipal);
    _safeTransfer(address(settlementAsset), expectedBorrowerPrincipal, amount);
    if (
      settlementAsset.balanceOf(address(this)) != vaultBalanceBefore - amount
        || settlementAsset.balanceOf(expectedBorrowerPrincipal) != recipientBalanceBefore + amount
    ) revert AssetBalanceMismatch();

    emit BorrowerRebateClaimed(expectedBorrowerPrincipal, amount);
    _finishSettlementIfComplete();
  }

  function redeem(uint256 noteAmount, address recipient)
    external
    nonReentrant
    returns (uint256 assetAmount)
  {
    if (state != BRCState.Redeemable) revert WrongState();
    if (noteAmount == 0) revert ZeroAmount();
    if (recipient == address(0)) revert ZeroAddress();
    uint256 ownerBalance = balanceOf[msg.sender];
    if (ownerBalance < noteAmount) revert InsufficientBalance();

    uint256 remainingReserve = uint256(noteholderReserve) - redeemedAssets;
    if (noteAmount == totalSupply) {
      assetAmount = remainingReserve;
    } else {
      assetAmount = uint256(noteholderReserve) * noteAmount / notional;
    }
    if (assetAmount > remainingReserve) revert AssetBalanceMismatch();

    balanceOf[msg.sender] = ownerBalance - noteAmount;
    totalSupply -= noteAmount;
    redeemedAssets += uint128(assetAmount);
    emit Transfer(msg.sender, address(0), noteAmount);

    uint256 vaultBalanceBefore = settlementAsset.balanceOf(address(this));
    uint256 recipientBalanceBefore = settlementAsset.balanceOf(recipient);
    _safeTransfer(address(settlementAsset), recipient, assetAmount);
    if (
      settlementAsset.balanceOf(address(this)) != vaultBalanceBefore - assetAmount
        || settlementAsset.balanceOf(recipient) != recipientBalanceBefore + assetAmount
    ) revert AssetBalanceMismatch();

    emit Redeemed(msg.sender, recipient, noteAmount, assetAmount, totalSupply);
    _finishSettlementIfComplete();
  }

  function setEligible(address account, bool eligible) external {
    if (msg.sender != accessController) revert NotAccessController();
    if (account == address(0)) revert ZeroAddress();
    isEligible[account] = eligible;
    emit EligibilitySet(account, eligible);
  }

  function approve(address spender, uint256 amount) external returns (bool) {
    if (spender == address(0)) revert ZeroAddress();
    if (transfersRestricted && amount != 0) {
      _requireEligible(msg.sender);
      _requireEligible(spender);
    }
    allowance[msg.sender][spender] = amount;
    emit Approval(msg.sender, spender, amount);
    return true;
  }

  function transfer(address recipient, uint256 amount) external returns (bool) {
    _checkTransferAccess(msg.sender, msg.sender, recipient);
    _transfer(msg.sender, recipient, amount);
    return true;
  }

  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
    _checkTransferAccess(msg.sender, sender, recipient);
    uint256 allowed = allowance[sender][msg.sender];
    if (allowed < amount) revert InsufficientAllowance();
    if (allowed != type(uint256).max) {
      allowance[sender][msg.sender] = allowed - amount;
      emit Approval(sender, msg.sender, allowed - amount);
    }
    _transfer(sender, recipient, amount);
    return true;
  }

  function subscribe(uint256 amount, address recipient) external nonReentrant {
    if (state != BRCState.Funding) revert WrongState();
    if (block.timestamp >= fundingDeadline || totalSupply == notional) revert FundingClosed();
    if (amount == 0) revert ZeroAmount();
    if (recipient == address(0)) revert ZeroAddress();
    if (amount > uint256(notional) - totalSupply) revert HardCapExceeded();
    if (transfersRestricted) {
      _requireEligible(msg.sender);
      _requireEligible(recipient);
    }

    uint256 balanceBefore = settlementAsset.balanceOf(address(this));
    if (balanceBefore < totalSupply) revert AssetBalanceMismatch();
    _safeTransferFrom(address(settlementAsset), msg.sender, address(this), amount);
    uint256 balanceAfter = settlementAsset.balanceOf(address(this));
    if (balanceAfter != balanceBefore + amount) revert AssetBalanceMismatch();

    totalSupply += amount;
    balanceOf[recipient] += amount;
    emit Transfer(address(0), recipient, amount);
    emit Subscribed(msg.sender, recipient, amount, totalSupply);
  }

  function finalizeFunding() external {
    if (state != BRCState.Funding) revert WrongState();
    if (totalSupply != notional && block.timestamp < fundingDeadline) revert FundingStillOpen();
    if (totalSupply < minimumRaise) revert RaiseFailed();
    if (settlementAsset.balanceOf(address(this)) < totalSupply) revert AssetBalanceMismatch();

    state = BRCState.Funded;
    emit FundingFinalized(totalSupply);
  }

  function cancelFunding() external {
    if (state != BRCState.Funding) revert WrongState();
    if (block.timestamp < fundingDeadline) revert FundingStillOpen();
    if (totalSupply >= minimumRaise) revert RaiseSucceeded();
    if (settlementAsset.balanceOf(address(this)) < totalSupply) revert AssetBalanceMismatch();

    state = BRCState.Cancelled;
    emit FundingCancelled(totalSupply);
  }

  function refund() external nonReentrant returns (uint256 amount) {
    if (state != BRCState.Cancelled) revert WrongState();
    amount = balanceOf[msg.sender];
    if (amount == 0) revert ZeroAmount();
    uint256 vaultBalanceBefore = settlementAsset.balanceOf(address(this));
    if (vaultBalanceBefore < totalSupply) revert AssetBalanceMismatch();

    balanceOf[msg.sender] = 0;
    totalSupply -= amount;
    emit Transfer(msg.sender, address(0), amount);

    uint256 recipientBalanceBefore = settlementAsset.balanceOf(msg.sender);
    _safeTransfer(address(settlementAsset), msg.sender, amount);
    if (
      settlementAsset.balanceOf(address(this)) != vaultBalanceBefore - amount
        || settlementAsset.balanceOf(msg.sender) != recipientBalanceBefore + amount
    ) {
      revert AssetBalanceMismatch();
    }
    emit Refunded(msg.sender, amount, totalSupply);
  }

  function _validateActivationPolicy()
    internal
    view
    returns (IWildcatActivationMarket market, FixedTermHooks hooks, address provider)
  {
    market = IWildcatActivationMarket(expectedMarket);
    MarketState memory marketState = market.previousState();
    if (
      expectedMarket.code.length == 0 || market.factory() != expectedHooksFactory
        || market.asset() != address(settlementAsset) || market.borrower() != expectedBorrower
        || market.borrowerPrincipal() != expectedBorrowerPrincipal
        || market.pendingBorrower() != address(0) || market.maxTotalSupply() != notional
        || market.annualInterestBips() != expectedAnnualInterestBips
        || market.reserveRatioBips() != expectedReserveRatioBips
        || market.delinquencyFeeBips() != expectedDelinquencyFeeBips
        || market.delinquencyGracePeriod() != expectedDelinquencyGracePeriod
        || market.withdrawalBatchDuration() != expectedWithdrawalBatchDuration
        || market.feeRecipient() != expectedFeeRecipient
        || marketState.protocolFeeBips != expectedProtocolFeeBips
        || IHooksFactoryView(expectedHooksFactory).computeMarketAddress(expectedMarketSalt)
          != expectedMarket
    ) revert ActivationPolicyMismatch();

    HooksConfig marketHooks = market.hooks();
    address hooksAddress = marketHooks.hooksAddress();
    if (
      hooksAddress.code.length == 0
        || IHooksFactoryView(expectedHooksFactory).getHooksTemplateForInstance(hooksAddress)
          != expectedHooksTemplate || !marketHooks.useOnDeposit() || !marketHooks.useOnTransfer()
        || !marketHooks.useOnQueueWithdrawal() || !marketHooks.useOnCloseMarket()
        || !marketHooks.useOnSetAnnualInterestAndReserveRatioBips()
    ) revert ActivationPolicyMismatch();

    hooks = FixedTermHooks(hooksAddress);
    if (
      keccak256(bytes(hooks.version())) != keccak256("SingletonFixedTermHooks")
        || hooks.administrator() != expectedBorrowerPrincipal
        || !hooks.roleProviderConfigurationSealed()
    ) revert ActivationPolicyMismatch();

    RoleProvider[] memory pullProviders = hooks.getPullProviders();
    RoleProvider[] memory pushProviders = hooks.getPushProviders();
    if (pullProviders.length != 1 || pushProviders.length != 0) {
      revert ActivationPolicyMismatch();
    }
    RoleProvider pullProvider = pullProviders[0];
    provider = pullProvider.providerAddress();
    if (
      pullProvider.timeToLive() != 0
        || RoleProvider.unwrap(hooks.getRoleProvider(provider)) != RoleProvider.unwrap(pullProvider)
        || expectedProviderFactory.codehash != expectedProviderFactoryCodeHash
        || ISingletonRoleProvider(provider).lender() != address(this)
    ) revert ActivationPolicyMismatch();

    SingletonRoleProviderFactoryInputs memory providerInputs =
      SingletonRoleProviderFactoryInputs({ lender: address(this), salt: expectedProviderSalt });
    if (
      ISingletonRoleProviderFactory(expectedProviderFactory)
          .computeRoleProviderAddress(hooksAddress, providerInputs) != provider
    ) revert ActivationPolicyMismatch();

    HookedMarket memory hookedMarket = hooks.getHookedMarket(expectedMarket);
    if (
      !hookedMarket.isHooked || !hookedMarket.depositRequiresAccess
        || !hookedMarket.transferRequiresAccess || hookedMarket.withdrawalRequiresAccess
        || !hookedMarket.transfersDisabled || hookedMarket.fixedTermEndTime != maturity
        || hookedMarket.allowClosureBeforeTerm || hookedMarket.allowTermReduction
    ) revert ActivationPolicyMismatch();
  }

  function _queueCompletePosition(uint32[] calldata preexistingExpiries)
    internal
    returns (uint32 expiry)
  {
    if (preexistingExpiries.length > 8) revert IncompleteMarketPerformance();

    IWildcatActivationMarket market = IWildcatActivationMarket(expectedMarket);
    uint256 totalQueuedScaled;
    for (uint256 i; i < preexistingExpiries.length; i++) {
      uint32 adoptedExpiry = preexistingExpiries[i];
      if (adoptedExpiry == 0) revert IncompleteMarketPerformance();
      for (uint256 j; j < i; j++) {
        if (preexistingExpiries[j] == adoptedExpiry) revert IncompleteMarketPerformance();
      }
      AccountWithdrawalStatus memory adoptedStatus =
        market.getAccountWithdrawalStatus(address(this), adoptedExpiry);
      if (adoptedStatus.scaledAmount == 0) revert IncompleteMarketPerformance();
      totalQueuedScaled += adoptedStatus.scaledAmount;
      isSettlementBatch[adoptedExpiry] = true;
      settlementBatchExpiries.push(adoptedExpiry);
      emit SettlementWithdrawalQueued(adoptedExpiry, adoptedStatus.scaledAmount, true);
    }

    uint256 liveScaledAmount = market.scaledBalanceOf(address(this));
    if (liveScaledAmount > 0) {
      uint256 duration = market.previousState().isClosed ? 0 : expectedWithdrawalBatchDuration;
      if (block.timestamp + duration + 1 > type(uint32).max) {
        revert SettlementQueueWindowClosed();
      }
      if (liveScaledAmount > type(uint104).max) revert IncompleteMarketPerformance();
      expiry = market.queueFullWithdrawal();
      if (isSettlementBatch[expiry]) revert IncompleteMarketPerformance();
      AccountWithdrawalStatus memory queuedStatus =
        market.getAccountWithdrawalStatus(address(this), expiry);
      if (queuedStatus.scaledAmount != liveScaledAmount) {
        revert IncompleteMarketPerformance();
      }
      totalQueuedScaled += liveScaledAmount;
      isSettlementBatch[expiry] = true;
      settlementBatchExpiries.push(expiry);
      emit SettlementWithdrawalQueued(expiry, uint104(liveScaledAmount), false);
    }
    if (
      totalQueuedScaled != activatedScaledAmount || market.scaledBalanceOf(address(this)) != 0
        || market.balanceOf(address(this)) != 0
    ) revert IncompleteMarketPerformance();
  }

  function _finishSettlementIfComplete() internal {
    if (totalSupply == 0 && borrowerRebateClaimed) state = BRCState.Settled;
  }

  function _transfer(address sender, address recipient, uint256 amount) internal {
    if (recipient == address(0)) revert ZeroAddress();
    uint256 senderBalance = balanceOf[sender];
    if (senderBalance < amount) revert InsufficientBalance();
    balanceOf[sender] = senderBalance - amount;
    balanceOf[recipient] += amount;
    emit Transfer(sender, recipient, amount);
  }

  function _checkTransferAccess(address operator, address sender, address recipient) internal view {
    if (!transfersRestricted) return;
    _requireEligible(operator);
    _requireEligible(sender);
    _requireEligible(recipient);
  }

  function _requireEligible(address account) internal view {
    if (!isEligible[account]) revert IneligibleAccount(account);
  }

  function _safeTransfer(address token, address recipient, uint256 amount) internal {
    (bool success, bytes memory result) =
      token.call(abi.encodeCall(IERC20.transfer, (recipient, amount)));
    if (!success || (result.length != 0 && (result.length != 32 || !abi.decode(result, (bool))))) {
      revert TransferFailed();
    }
  }

  function _safeTransferFrom(address token, address sender, address recipient, uint256 amount)
    internal
  {
    (bool success, bytes memory result) =
      token.call(abi.encodeCall(IERC20.transferFrom, (sender, recipient, amount)));
    if (!success || (result.length != 0 && (result.length != 32 || !abi.decode(result, (bool))))) {
      revert TransferFailed();
    }
  }

  function _safeApprove(address token, address spender, uint256 amount) internal {
    (bool success, bytes memory result) =
      token.call(abi.encodeCall(IERC20.approve, (spender, amount)));
    if (!success || (result.length != 0 && (result.length != 32 || !abi.decode(result, (bool))))) {
      revert TransferFailed();
    }
  }
}
