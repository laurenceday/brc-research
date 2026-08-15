// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { stdStorage, StdStorage, Test } from "forge-std/Test.sol";
import {
  ActivationTerms,
  BRCNoteVault,
  IHooksFactoryView,
  IWildcatActivationMarket
} from "../src/BRCNoteVault.sol";
import { BRCFallbackConfig } from "../src/BRCFallback.sol";
import { BRCState } from "../src/BRCSeries.sol";
import { IERC20Metadata } from "../src/interfaces/IERC20.sol";
import { HooksFactory } from "v2-protocol/HooksFactory.sol";
import { WildcatArchController } from "v2-protocol/WildcatArchController.sol";
import { WildcatBorrowerIdentityRegistry } from "v2-protocol/WildcatBorrowerIdentityRegistry.sol";
import { WildcatSanctionsSentinel } from "v2-protocol/WildcatSanctionsSentinel.sol";
import { BaseAccessControls } from "v2-protocol/access/BaseAccessControls.sol";
import { FixedTermHooks, HookedMarket } from "v2-protocol/access/FixedTermHooks.sol";
import {
  SingletonFixedTermHooks,
  SingletonFixedTermHooksInputs
} from "v2-protocol/access/SingletonFixedTermHooks.sol";
import {
  CreateProviderInputs,
  NameAndProviderInputs
} from "v2-protocol/access/ProviderStructs.sol";
import { DeployMarketInputs } from "v2-protocol/interfaces/WildcatStructsAndEnums.sol";
import { LibStoredInitCode } from "v2-protocol/libraries/LibStoredInitCode.sol";
import { MarketState } from "v2-protocol/libraries/MarketState.sol";
import { WildcatMarket } from "v2-protocol/market/WildcatMarket.sol";
import {
  SingletonRoleProviderFactoryInputs
} from "v2-protocol/providers/ISingletonRoleProviderFactory.sol";
import {
  SingletonRoleProviderFactory
} from "v2-protocol/providers/SingletonRoleProviderFactory.sol";
import { ISingletonRoleProvider } from "v2-protocol/providers/ISingletonRoleProvider.sol";
import {
  Bit_Enabled_CloseMarket,
  Bit_Enabled_Deposit,
  Bit_Enabled_QueueWithdrawal,
  Bit_Enabled_SetAnnualInterestAndReserveRatioBips,
  Bit_Enabled_Transfer,
  encodeHooksConfig,
  HooksConfig,
  LibHooksConfig
} from "v2-protocol/types/HooksConfig.sol";
import { LibRoleProvider, RoleProvider } from "v2-protocol/types/RoleProvider.sol";
import { Wildcat4626WrapperFactory } from "v2-protocol/vault/Wildcat4626WrapperFactory.sol";
import { MockAggregatorV3 } from "./mocks/MockAggregatorV3.sol";
import { MockChainalysis } from "./mocks/MockChainalysis.sol";
import { MockChainlinkProxy } from "./mocks/MockChainlinkProxy.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

contract MockOperationalBorrower {
  function execute(address target, bytes calldata data) external returns (bytes memory result) {
    (bool success, bytes memory returnData) = target.call(data);
    if (!success) {
      assembly ("memory-safe") {
        revert(add(returnData, 0x20), mload(returnData))
      }
    }
    return returnData;
  }
}

contract BRCActivationTest is Test {
  using stdStorage for StdStorage;
  using LibHooksConfig for HooksConfig;
  using LibRoleProvider for RoleProvider;

  uint128 internal constant NOTIONAL = 1_000_000e6;
  uint16 internal constant APR = 1_200;
  uint16 internal constant RESERVE_RATIO = 1_000;
  uint16 internal constant DELINQUENCY_FEE = 0;
  uint32 internal constant DELINQUENCY_GRACE_PERIOD = 1 days;
  uint32 internal constant WITHDRAWAL_BATCH_DURATION = 1 days;
  address internal constant FEE_RECIPIENT = address(0);
  uint16 internal constant PROTOCOL_FEE = 0;
  uint16 internal constant BARRIER_BIPS = 6_000;
  uint256 internal constant RATIFIER_ONE_KEY = 0xA11CE;
  uint256 internal constant RATIFIER_TWO_KEY = 0xB0B;
  uint256 internal constant RATIFIER_THREE_KEY = 0xCAFE;
  bytes32 internal constant PROVIDER_SALT = keccak256("brc-provider");
  bytes32 internal constant DESCRIPTION_HASH = keccak256("BTC / USD");

  WildcatArchController internal archController;
  WildcatBorrowerIdentityRegistry internal borrowerRegistry;
  WildcatSanctionsSentinel internal sanctionsSentinel;
  MockChainalysis internal chainalysis;
  Wildcat4626WrapperFactory internal wrapperFactory;
  HooksFactory internal hooksFactory;
  SingletonRoleProviderFactory internal providerFactory;
  MockERC20 internal asset;
  MockAggregatorV3 internal feed;
  MockChainlinkProxy internal feedProxy;
  BRCNoteVault internal vault;
  WildcatMarket internal market;
  SingletonFixedTermHooks internal hooks;
  address internal hooksTemplate;
  bytes32 internal marketSalt;
  uint40 internal fundingDeadline;
  uint40 internal activationDeadline;
  uint40 internal maturity;

  function setUp() external {
    vm.warp(10 days);
    fundingDeadline = uint40(block.timestamp + 7 days);
    activationDeadline = uint40(block.timestamp + 21 days);
    maturity = uint40(block.timestamp + 30 days);
    asset = new MockERC20("USD Coin", "USDC", 6);
    feed = new MockAggregatorV3(8, "BTC / USD");
    feed.setRound(1, 100_000e8, block.timestamp, block.timestamp, 1);
    feedProxy = new MockChainlinkProxy(8, "BTC / USD");
    feedProxy.setPhase(1, feed);

    archController = new WildcatArchController();
    borrowerRegistry = new WildcatBorrowerIdentityRegistry(address(archController));
    chainalysis = new MockChainalysis();
    sanctionsSentinel = new WildcatSanctionsSentinel(address(archController), address(chainalysis));
    wrapperFactory = new Wildcat4626WrapperFactory(address(archController), address(0));
    address marketInitCode = LibStoredInitCode.deployInitCode(type(WildcatMarket).creationCode);
    hooksFactory = new HooksFactory(
      address(archController),
      address(sanctionsSentinel),
      address(wrapperFactory),
      marketInitCode,
      uint256(keccak256(type(WildcatMarket).creationCode)),
      address(borrowerRegistry)
    );
    archController.registerControllerFactory(address(hooksFactory));
    hooksFactory.registerWithArchController();
    archController.registerBorrower(address(this));

    providerFactory = new SingletonRoleProviderFactory();
    hooksTemplate = LibStoredInitCode.deployInitCode(type(SingletonFixedTermHooks).creationCode);
    hooksFactory.addHooksTemplate(
      hooksTemplate, "SingletonFixedTermHooks", address(0), address(0), 0, 0
    );

    marketSalt = bytes32((uint256(uint160(address(this))) << 96) | uint256(1));
    address expectedMarket = hooksFactory.computeMarketAddress(marketSalt);
    vault = new BRCNoteVault(
      IERC20Metadata(address(asset)),
      address(this),
      "Wildcat BTC BRC Note",
      "wcBRC-BTC",
      NOTIONAL,
      NOTIONAL,
      fundingDeadline,
      true,
      _activationTerms(expectedMarket)
    );

    (address marketAddress, address hooksAddress) = hooksFactory.deployMarketAndHooks(
      hooksTemplate,
      _hooksConstructorArgs(),
      _marketInputs(),
      abi.encode(uint32(maturity), uint128(0), true, false, false),
      marketSalt,
      address(0),
      0
    );
    market = WildcatMarket(marketAddress);
    hooks = SingletonFixedTermHooks(hooksAddress);

    vault.setEligible(address(this), true);
    asset.mint(address(this), NOTIONAL);
    asset.approve(address(vault), NOTIONAL);
    vault.subscribe(NOTIONAL, address(this));
    vault.finalizeFunding();
  }

  function testActivatesAgainstPinnedSingletonFixedTermDeployment() external {
    vault.activate();

    assertEq(uint256(vault.state()), uint256(BRCState.Active));
    assertTrue(vault.fixingOracle().hasInitialFixing());
    assertEq(market.balanceOf(address(vault)), NOTIONAL);
    assertEq(asset.balanceOf(address(vault)), 0);
    assertEq(asset.allowance(address(vault), address(market)), 0);
  }

  function testActivationWorksWithZeroFirstApprovalToken() external {
    asset.setRequireZeroBeforeApprove(true);

    vault.activate();

    assertEq(asset.allowance(address(vault), address(market)), 0);
    assertEq(market.balanceOf(address(vault)), NOTIONAL);
  }

  function testActivationAcceptsPinnedScaleRoundingAfterDelay() external {
    vm.warp(block.timestamp + 10 days);

    vault.activate();

    assertEq(uint256(vault.state()), uint256(BRCState.Active));
    assertEq(asset.balanceOf(address(market)), NOTIONAL);
    assertEq(market.balanceOf(address(vault)), NOTIONAL - 1);
    assertGt(market.scaledBalanceOf(address(vault)), 0);
  }

  function testActivationRejectsFeeOnTransferIntoMarket() external {
    asset.setFeeBips(100);

    vm.expectRevert(BRCNoteVault.AssetBalanceMismatch.selector);
    vault.activate();

    assertTrue(vault.fixingOracle().hasInitialFixing());
    assertEq(uint256(vault.state()), uint256(BRCState.Funded));
  }

  function testAnyoneCanActivatePrecommittedInitialFixing() external {
    vm.prank(address(0xB0B));
    vault.activate();

    (, uint128 price,) = vault.fixingOracle().initialFixing();
    assertEq(price, 100_000e8);
    assertEq(uint256(vault.state()), uint256(BRCState.Active));
  }

  function testActivatesCanonicalDelegatedBorrowerDeployment() external {
    MockOperationalBorrower operationalBorrower = new MockOperationalBorrower();
    borrowerRegistry.addAccountFactory(address(this));
    borrowerRegistry.registerBorrowerAccount(address(operationalBorrower), address(this));

    bytes32 delegatedSalt =
      bytes32((uint256(uint160(address(operationalBorrower))) << 96) | uint256(2));
    address delegatedMarketAddress = hooksFactory.computeMarketAddress(delegatedSalt);
    ActivationTerms memory terms = _activationTerms(delegatedMarketAddress);
    terms.borrower = address(operationalBorrower);
    terms.borrowerPrincipal = address(this);
    terms.marketSalt = delegatedSalt;
    BRCNoteVault delegatedVault = new BRCNoteVault(
      IERC20Metadata(address(asset)),
      address(this),
      "Delegated Wildcat BTC BRC Note",
      "d-wcBRC-BTC",
      NOTIONAL,
      NOTIONAL,
      fundingDeadline,
      true,
      terms
    );

    bytes memory deploymentResult = operationalBorrower.execute(
      address(hooksFactory),
      abi.encodeWithSelector(
        HooksFactory.deployMarketAndHooks.selector,
        hooksTemplate,
        _hooksConstructorArgsFor(address(delegatedVault)),
        _marketInputs(),
        abi.encode(uint32(maturity), uint128(0), true, false, false),
        delegatedSalt,
        address(0),
        0
      )
    );
    (address deployedMarket, address deployedHooks) =
      abi.decode(deploymentResult, (address, address));
    assertEq(deployedMarket, delegatedMarketAddress);
    assertEq(FixedTermHooks(deployedHooks).administrator(), address(this));
    assertEq(IWildcatActivationMarket(deployedMarket).borrower(), address(operationalBorrower));
    assertEq(IWildcatActivationMarket(deployedMarket).borrowerPrincipal(), address(this));

    delegatedVault.setEligible(address(this), true);
    asset.mint(address(this), NOTIONAL);
    asset.approve(address(delegatedVault), NOTIONAL);
    delegatedVault.subscribe(NOTIONAL, address(this));
    delegatedVault.finalizeFunding();
    delegatedVault.activate();

    assertEq(uint256(delegatedVault.state()), uint256(BRCState.Active));
  }

  function testDepositFailureKeepsPrecommittedFixingAndRollsBackAllowance() external {
    asset.setFailTransfers(true);

    vm.expectRevert();
    vault.activate();

    assertTrue(vault.fixingOracle().hasInitialFixing());
    assertEq(asset.allowance(address(vault), address(market)), 0);
    assertEq(uint256(vault.state()), uint256(BRCState.Funded));
  }

  function testFundedVaultCanCancelAndRefundAfterActivationDeadline() external {
    vm.warp(activationDeadline);
    vault.cancelUnactivated();

    assertEq(uint256(vault.state()), uint256(BRCState.Cancelled));
    vault.refund();
    assertEq(vault.totalSupply(), 0);
    assertEq(asset.balanceOf(address(this)), NOTIONAL);
  }

  function testCannotCancelWhileActivationWindowIsOpen() external {
    vm.expectRevert(BRCNoteVault.ActivationStillOpen.selector);
    vault.cancelUnactivated();
  }

  function testCannotActivateAtDeadline() external {
    vm.warp(activationDeadline);
    vm.expectRevert(BRCNoteVault.ActivationWindowClosed.selector);
    vault.activate();
  }

  function testConstructorRejectsMarketOutsideBoundFactorySalt() external {
    ActivationTerms memory terms = _activationTerms(address(0xBEEF));
    vm.expectRevert(BRCNoteVault.InvalidTerms.selector);
    new BRCNoteVault(
      IERC20Metadata(address(asset)),
      address(this),
      "Bad binding",
      "BAD",
      NOTIONAL,
      NOTIONAL,
      fundingDeadline,
      true,
      terms
    );
  }

  function testConstructorRejectsPartialRaiseForConfiguredActivation() external {
    ActivationTerms memory terms = _activationTerms(address(market));
    vm.expectRevert(BRCNoteVault.InvalidTerms.selector);
    new BRCNoteVault(
      IERC20Metadata(address(asset)),
      address(this),
      "Partial configured raise",
      "PART",
      NOTIONAL,
      NOTIONAL / 2,
      fundingDeadline,
      true,
      terms
    );
  }

  function testConstructorRejectsNotionalAboveWildcatAccountWidth() external {
    ActivationTerms memory terms = _activationTerms(address(market));
    uint128 oversized = uint128(type(uint104).max) + 1;
    vm.expectRevert(BRCNoteVault.InvalidTerms.selector);
    new BRCNoteVault(
      IERC20Metadata(address(asset)),
      address(this),
      "Oversized account",
      "WIDE",
      oversized,
      oversized,
      fundingDeadline,
      true,
      terms
    );
  }

  function testConstructorRejectsWildcardMarketSalt() external {
    ActivationTerms memory terms = _activationTerms(address(market));
    terms.marketSalt = bytes32(uint256(1));
    terms.market = hooksFactory.computeMarketAddress(terms.marketSalt);
    vm.expectRevert(BRCNoteVault.InvalidTerms.selector);
    new BRCNoteVault(
      IERC20Metadata(address(asset)),
      address(this),
      "Wildcard market salt",
      "WILD",
      NOTIONAL,
      NOTIONAL,
      fundingDeadline,
      true,
      terms
    );
  }

  function testConstructorReservesRoomForMaturitySettlement() external {
    ActivationTerms memory terms = _activationTerms(address(market));
    terms.maturity = type(uint32).max - terms.maxObservationDelay - terms.withdrawalBatchDuration;
    vm.expectRevert(BRCNoteVault.InvalidTerms.selector);
    new BRCNoteVault(
      IERC20Metadata(address(asset)),
      address(this),
      "Unsafe settlement horizon",
      "LATE",
      NOTIONAL,
      NOTIONAL,
      fundingDeadline,
      true,
      terms
    );
  }

  function testRejectsProviderFactoryRuntimeOutsideManifest() external {
    vm.etch(address(providerFactory), hex"00");
    vm.expectRevert(BRCNoteVault.ActivationPolicyMismatch.selector);
    vault.activate();
  }

  function testRejectsPreStagedBorrowerTransfer() external {
    address nextBorrower = address(0xB0B);
    archController.registerBorrower(nextBorrower);
    market.requestBorrowerTransfer(nextBorrower);

    vm.expectRevert(BRCNoteVault.ActivationPolicyMismatch.selector);
    vault.activate();
  }

  function testRejectsEveryMarketManifestMismatch() external {
    _expectPolicyMismatch(
      address(market), abi.encodeCall(IWildcatActivationMarket.factory, ()), abi.encode(address(1))
    );
    _expectPolicyMismatch(
      address(market), abi.encodeCall(IWildcatActivationMarket.asset, ()), abi.encode(address(1))
    );
    _expectPolicyMismatch(
      address(market), abi.encodeCall(IWildcatActivationMarket.borrower, ()), abi.encode(address(1))
    );
    _expectPolicyMismatch(
      address(market),
      abi.encodeCall(IWildcatActivationMarket.borrowerPrincipal, ()),
      abi.encode(address(1))
    );
    _expectPolicyMismatch(
      address(market),
      abi.encodeCall(IWildcatActivationMarket.pendingBorrower, ()),
      abi.encode(address(1))
    );
    _expectPolicyMismatch(
      address(market), abi.encodeCall(IWildcatActivationMarket.maxTotalSupply, ()), abi.encode(1)
    );
    _expectPolicyMismatch(
      address(market),
      abi.encodeCall(IWildcatActivationMarket.annualInterestBips, ()),
      abi.encode(1)
    );
    _expectPolicyMismatch(
      address(market), abi.encodeCall(IWildcatActivationMarket.reserveRatioBips, ()), abi.encode(1)
    );
    _expectPolicyMismatch(
      address(market),
      abi.encodeCall(IWildcatActivationMarket.delinquencyFeeBips, ()),
      abi.encode(1)
    );
    _expectPolicyMismatch(
      address(market),
      abi.encodeCall(IWildcatActivationMarket.delinquencyGracePeriod, ()),
      abi.encode(2 days)
    );
    _expectPolicyMismatch(
      address(market),
      abi.encodeCall(IWildcatActivationMarket.withdrawalBatchDuration, ()),
      abi.encode(365 days)
    );
    _expectPolicyMismatch(
      address(market),
      abi.encodeCall(IWildcatActivationMarket.feeRecipient, ()),
      abi.encode(address(1))
    );
    MarketState memory badState = market.previousState();
    badState.protocolFeeBips = 1;
    _expectPolicyMismatch(
      address(market),
      abi.encodeCall(IWildcatActivationMarket.previousState, ()),
      abi.encode(badState)
    );
  }

  function testRejectsWrongTemplateAndUnsealedProviderSet() external {
    _expectPolicyMismatch(
      address(hooksFactory),
      abi.encodeCall(IHooksFactoryView.getHooksTemplateForInstance, (address(hooks))),
      abi.encode(address(1))
    );
    _expectPolicyMismatch(
      address(hooks), abi.encodeCall(hooks.roleProviderConfigurationSealed, ()), abi.encode(false)
    );
    _expectPolicyMismatch(
      address(hooks), abi.encodeCall(hooks.version, ()), abi.encode("NotSingletonFixedTermHooks")
    );
  }

  function testRejectsMissingRequiredHookDispatch() external {
    HooksConfig current = market.hooks();
    _expectHooksConfigMismatch(current.clearFlag(Bit_Enabled_Deposit));
    _expectHooksConfigMismatch(current.clearFlag(Bit_Enabled_Transfer));
    _expectHooksConfigMismatch(current.clearFlag(Bit_Enabled_QueueWithdrawal));
    _expectHooksConfigMismatch(current.clearFlag(Bit_Enabled_CloseMarket));
    _expectHooksConfigMismatch(current.clearFlag(Bit_Enabled_SetAnnualInterestAndReserveRatioBips));
  }

  function testRejectsProviderCountTtlLenderAndFactoryMismatch() external {
    RoleProvider[] memory noProviders = new RoleProvider[](0);
    _expectPolicyMismatch(
      address(hooks), abi.encodeCall(hooks.getPullProviders, ()), abi.encode(noProviders)
    );

    RoleProvider[] memory pushProviders = new RoleProvider[](1);
    pushProviders[0] = RoleProvider.wrap(1);
    _expectPolicyMismatch(
      address(hooks), abi.encodeCall(hooks.getPushProviders, ()), abi.encode(pushProviders)
    );

    RoleProvider providerRecord = hooks.getPullProviders()[0];
    RoleProvider[] memory wrongTtl = new RoleProvider[](1);
    wrongTtl[0] = RoleProvider.wrap(RoleProvider.unwrap(providerRecord) | (uint256(1) << 224));
    _expectPolicyMismatch(
      address(hooks), abi.encodeCall(hooks.getPullProviders, ()), abi.encode(wrongTtl)
    );

    address provider = providerRecord.providerAddress();
    _expectPolicyMismatch(
      provider, abi.encodeCall(ISingletonRoleProvider.lender, ()), abi.encode(1)
    );

    SingletonRoleProviderFactoryInputs memory inputs =
      SingletonRoleProviderFactoryInputs({ lender: address(vault), salt: PROVIDER_SALT });
    _expectPolicyMismatch(
      address(providerFactory),
      abi.encodeCall(providerFactory.computeRoleProviderAddress, (address(hooks), inputs)),
      abi.encode(address(1))
    );
  }

  function testRejectsEveryStoredFixedTermMismatch() external {
    HookedMarket memory policy = hooks.getHookedMarket(address(market));

    policy.depositRequiresAccess = false;
    _expectHookedMarketMismatch(policy);
    policy.depositRequiresAccess = true;
    policy.transferRequiresAccess = false;
    _expectHookedMarketMismatch(policy);
    policy.transferRequiresAccess = true;
    policy.withdrawalRequiresAccess = true;
    _expectHookedMarketMismatch(policy);
    policy.withdrawalRequiresAccess = false;
    policy.transfersDisabled = false;
    _expectHookedMarketMismatch(policy);
    policy.transfersDisabled = true;
    policy.fixedTermEndTime -= 1;
    _expectHookedMarketMismatch(policy);
    policy.fixedTermEndTime += 1;
    policy.allowClosureBeforeTerm = true;
    _expectHookedMarketMismatch(policy);
    policy.allowClosureBeforeTerm = false;
    policy.allowTermReduction = true;
    _expectHookedMarketMismatch(policy);
  }

  function testRejectsPreexistingMarketSupplyOrVaultPosition() external {
    _expectPolicyMismatch(
      address(market), abi.encodeCall(IWildcatActivationMarket.totalSupply, ()), abi.encode(1)
    );
    _expectPolicyMismatch(
      address(market),
      abi.encodeCall(IWildcatActivationMarket.balanceOf, (address(vault))),
      abi.encode(1)
    );
    _expectPolicyMismatch(
      address(market),
      abi.encodeCall(IWildcatActivationMarket.scaledBalanceOf, (address(vault))),
      abi.encode(1)
    );
  }

  function testMarketTokensCannotMoveToUnrelatedRecipient() external {
    vault.activate();

    vm.prank(address(vault));
    vm.expectRevert(FixedTermHooks.TransfersDisabled.selector);
    market.transfer(address(0xB0B), 1);
  }

  function testRejectsRepeatedAndUnconfiguredActivation() external {
    vault.activate();
    vm.expectRevert(BRCNoteVault.WrongState.selector);
    vault.activate();

    BRCNoteVault partialVault = new BRCNoteVault(
      IERC20Metadata(address(asset)),
      address(this),
      "Partial",
      "PART",
      NOTIONAL,
      NOTIONAL / 2,
      fundingDeadline,
      false,
      ActivationTerms({
        seriesManifestHash: bytes32(0),
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
        maxObservationDelay: 0,
        recoveryDelay: 0,
        writeOffDelay: 0,
        fallbackConfig: BRCFallbackConfig({
          ratifiers: new address[](0),
          threshold: 0,
          waitingPeriod: 0,
          challengePeriod: 0,
          sourceId: bytes32(0)
        })
      })
    );
    vm.expectRevert(BRCNoteVault.ActivationNotConfigured.selector);
    partialVault.activate();
  }

  function testRejectsPartialNotionalActivation() external {
    stdstore.target(address(vault)).sig(vault.totalSupply.selector).checked_write(NOTIONAL - 1);

    vm.expectRevert(BRCNoteVault.IncompleteRaise.selector);
    vault.activate();
  }

  function testPinnedHooksBlockPolicyChangesAndProviderMutation() external {
    vm.expectRevert(FixedTermHooks.ClosureDisabledBeforeTerm.selector);
    market.closeMarket();

    vm.expectRevert(FixedTermHooks.TermReductionDisabled.selector);
    hooks.setFixedTermEndTime(address(market), uint32(block.timestamp));

    vm.expectRevert(SingletonFixedTermHooks.RateOrReserveRatioChangeBeforeTermEnd.selector);
    market.setAnnualInterestAndReserveRatioBips(APR + 1, RESERVE_RATIO);

    address provider = hooks.getPullProviders()[0].providerAddress();
    vm.expectRevert(BaseAccessControls.RoleProviderConfigurationAlreadySealed.selector);
    hooks.removeRoleProvider(provider);

    vm.expectRevert(BaseAccessControls.RoleProviderConfigurationAlreadySealed.selector);
    hooks.addRoleProvider(provider, 0);

    vm.expectRevert(BaseAccessControls.RoleProviderConfigurationAlreadySealed.selector);
    hooks.createRoleProvider(address(providerFactory), 0, abi.encode(address(vault), bytes32(0)));
  }

  function _expectHooksConfigMismatch(HooksConfig badConfig) internal {
    _expectPolicyMismatch(
      address(market), abi.encodeCall(IWildcatActivationMarket.hooks, ()), abi.encode(badConfig)
    );
  }

  function _expectHookedMarketMismatch(HookedMarket memory badPolicy) internal {
    _expectPolicyMismatch(
      address(hooks),
      abi.encodeCall(hooks.getHookedMarket, (address(market))),
      abi.encode(badPolicy)
    );
  }

  function _expectPolicyMismatch(address target, bytes memory callData, bytes memory returnData)
    internal
  {
    vm.mockCall(target, callData, returnData);
    vm.expectRevert(BRCNoteVault.ActivationPolicyMismatch.selector);
    vault.activate();
    vm.clearMockedCalls();
  }

  function _activationTerms(address expectedMarket) internal view returns (ActivationTerms memory) {
    return ActivationTerms({
      seriesManifestHash: keccak256("test manifest"),
      market: expectedMarket,
      borrower: address(this),
      borrowerPrincipal: address(this),
      hooksFactory: address(hooksFactory),
      hooksTemplate: hooksTemplate,
      providerFactory: address(providerFactory),
      providerFactoryCodeHash: address(providerFactory).codehash,
      marketSalt: marketSalt,
      providerSalt: PROVIDER_SALT,
      annualInterestBips: APR,
      reserveRatioBips: RESERVE_RATIO,
      delinquencyFeeBips: DELINQUENCY_FEE,
      delinquencyGracePeriod: DELINQUENCY_GRACE_PERIOD,
      withdrawalBatchDuration: WITHDRAWAL_BATCH_DURATION,
      feeRecipient: FEE_RECIPIENT,
      protocolFeeBips: PROTOCOL_FEE,
      activationDeadline: activationDeadline,
      maturity: maturity,
      btcUsdFeed: address(feedProxy),
      feedDecimals: 8,
      feedDescriptionHash: DESCRIPTION_HASH,
      maxInitialAge: 1 hours,
      maxFutureSkew: 30 seconds,
      barrierBips: BARRIER_BIPS,
      maxObservationDelay: 1 hours,
      recoveryDelay: 2 days,
      writeOffDelay: 30 days,
      fallbackConfig: _fallbackConfig()
    });
  }

  function _fallbackConfig() internal pure returns (BRCFallbackConfig memory config) {
    config.ratifiers = new address[](3);
    config.ratifiers[0] = vm.addr(RATIFIER_ONE_KEY);
    config.ratifiers[1] = vm.addr(RATIFIER_TWO_KEY);
    config.ratifiers[2] = vm.addr(RATIFIER_THREE_KEY);
    config.threshold = 2;
    config.waitingPeriod = 1 days;
    config.challengePeriod = 1 days;
    config.sourceId = keccak256("BTC fallback");
  }

  function _hooksConstructorArgs() internal view returns (bytes memory) {
    return _hooksConstructorArgsFor(address(vault));
  }

  function _hooksConstructorArgsFor(address lender) internal view returns (bytes memory) {
    SingletonRoleProviderFactoryInputs memory providerInputs =
      SingletonRoleProviderFactoryInputs({ lender: lender, salt: PROVIDER_SALT });
    NameAndProviderInputs memory accessInputs;
    accessInputs.name = "BRC singleton lender";
    accessInputs.roleProviderFactory = address(providerFactory);
    accessInputs.newProviderInputs = new CreateProviderInputs[](1);
    accessInputs.newProviderInputs[0] =
      CreateProviderInputs({ timeToLive: 0, providerFactoryCalldata: abi.encode(providerInputs) });
    return abi.encode(SingletonFixedTermHooksInputs(accessInputs, lender));
  }

  function _marketInputs() internal view returns (DeployMarketInputs memory) {
    return DeployMarketInputs({
      asset: address(asset),
      namePrefix: "Wildcat ",
      symbolPrefix: "WC",
      maxTotalSupply: NOTIONAL,
      annualInterestBips: APR,
      delinquencyFeeBips: DELINQUENCY_FEE,
      withdrawalBatchDuration: WITHDRAWAL_BATCH_DURATION,
      reserveRatioBips: RESERVE_RATIO,
      delinquencyGracePeriod: DELINQUENCY_GRACE_PERIOD,
      hooks: encodeHooksConfig({
        hooksAddress: address(0),
        useOnDeposit: true,
        useOnQueueWithdrawal: false,
        useOnExecuteWithdrawal: false,
        useOnTransfer: true,
        useOnBorrow: false,
        useOnRepay: false,
        useOnCloseMarket: false,
        useOnNukeFromOrbit: false,
        useOnSetMaxTotalSupply: false,
        useOnSetAnnualInterestAndReserveRatioBips: false,
        useOnSetProtocolFeeBips: false
      })
    });
  }
}
