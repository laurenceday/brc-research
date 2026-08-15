// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { BRCJson } from "../script/BRCJson.sol";
import {
  BRCBuildManifest,
  BRCDeploymentLib,
  BRCDeploymentRecord,
  BRCDeploymentVerifier,
  BRCGovernanceManifest,
  BRCHooksManifest,
  BRCMarketManifest,
  BRCOracleManifest,
  BRCSeriesManifest,
  BRCVaultManifest
} from "../src/BRCDeployment.sol";
import { BRCNoteVault } from "../src/BRCNoteVault.sol";
import {
  BRCAtomicDeployment,
  BRCBorrowerAccount,
  BRCBorrowerAccountFactory
} from "../src/BRCBorrowerAccount.sol";
import { BRCVaultFactory } from "../src/BRCVaultFactory.sol";
import { BtcUsdFixingOracle } from "../src/BtcUsdFixingOracle.sol";
import { HooksFactory } from "v2-protocol/HooksFactory.sol";
import { WildcatArchController } from "v2-protocol/WildcatArchController.sol";
import { WildcatBorrowerIdentityRegistry } from "v2-protocol/WildcatBorrowerIdentityRegistry.sol";
import { WildcatSanctionsSentinel } from "v2-protocol/WildcatSanctionsSentinel.sol";
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
import { WildcatMarket } from "v2-protocol/market/WildcatMarket.sol";
import {
  SingletonRoleProviderFactoryInputs
} from "v2-protocol/providers/ISingletonRoleProviderFactory.sol";
import {
  SingletonRoleProviderFactory
} from "v2-protocol/providers/SingletonRoleProviderFactory.sol";
import { HooksConfig, LibHooksConfig } from "v2-protocol/types/HooksConfig.sol";
import { Wildcat4626WrapperFactory } from "v2-protocol/vault/Wildcat4626WrapperFactory.sol";
import { MockAggregatorV3 } from "./mocks/MockAggregatorV3.sol";
import { MockChainalysis } from "./mocks/MockChainalysis.sol";
import { MockChainlinkProxy } from "./mocks/MockChainlinkProxy.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

contract BRCJsonHarness is BRCJson {
  function parse(string memory json) external view returns (BRCSeriesManifest memory) {
    return _loadManifest(json, "");
  }
}

contract BRCDeploymentTest is Test {
  using LibHooksConfig for HooksConfig;

  uint128 internal constant NOTIONAL = 1_000_000e6;
  bytes32 internal constant DESCRIPTION_HASH = keccak256("BTC / USD");

  HooksFactory internal hooksFactory;
  WildcatArchController internal archController;
  WildcatBorrowerIdentityRegistry internal borrowerRegistry;
  BRCBorrowerAccount internal borrowerAccount;
  SingletonRoleProviderFactory internal providerFactory;
  BRCVaultFactory internal vaultFactory;
  MockERC20 internal asset;
  MockChainlinkProxy internal feed;
  address internal hooksTemplate;
  BRCSeriesManifest internal manifest;
  BRCDeploymentVerifier internal verifier;

  function setUp() external {
    vm.warp(10 days);
    asset = new MockERC20("USD Coin", "USDC", 6);
    MockAggregatorV3 aggregator = new MockAggregatorV3(8, "BTC / USD");
    aggregator.setRound(1, 100_000e8, block.timestamp, block.timestamp, 1);
    feed = new MockChainlinkProxy(8, "BTC / USD");
    feed.setPhase(1, aggregator);

    archController = new WildcatArchController();
    borrowerRegistry = new WildcatBorrowerIdentityRegistry(address(archController));
    WildcatSanctionsSentinel sanctionsSentinel =
      new WildcatSanctionsSentinel(address(archController), address(new MockChainalysis()));
    Wildcat4626WrapperFactory wrapperFactory =
      new Wildcat4626WrapperFactory(address(archController), address(0));
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

    BRCBorrowerAccountFactory borrowerAccountFactory =
      new BRCBorrowerAccountFactory(address(borrowerRegistry));
    borrowerRegistry.addAccountFactory(address(borrowerAccountFactory));
    borrowerAccount = borrowerAccountFactory.deployAccount(address(this));

    providerFactory = new SingletonRoleProviderFactory();
    vaultFactory = new BRCVaultFactory();
    hooksTemplate = LibStoredInitCode.deployInitCode(type(SingletonFixedTermHooks).creationCode);
    hooksFactory.addHooksTemplate(
      hooksTemplate, "SingletonFixedTermHooks", address(0), address(0), 0, 0
    );
    verifier = new BRCDeploymentVerifier();
    manifest = _manifest();
  }

  function testLocalDeploymentMatchesEveryCalculatedAddressAndPolicy() external {
    BRCDeploymentRecord memory record = _deploy(manifest);

    assertTrue(verifier.verify(manifest, record));
    assertEq(record.market, BRCDeploymentLib.marketAddress(manifest));
    assertEq(record.hooks, BRCDeploymentLib.hooksAddress(manifest, record.vault));
    assertEq(
      record.provider, BRCDeploymentLib.providerAddress(manifest, record.hooks, record.vault)
    );
    assertEq(asset.allowance(address(borrowerAccount), address(hooksFactory)), 0);
  }

  function testRecordedDeploymentStillVerifiesAfterFundingDeadline() external {
    BRCDeploymentRecord memory record = _deploy(manifest);
    vm.warp(manifest.vault.fundingDeadline + 1);
    assertTrue(verifier.verify(manifest, record));
  }

  function testSameStateAndInputsReproduceEveryAddress() external {
    uint256 snapshot = vm.snapshotState();
    BRCDeploymentRecord memory first = _deploy(manifest);
    assertTrue(vm.revertToState(snapshot));

    BRCDeploymentRecord memory second = _deploy(manifest);
    assertEq(first.vault, second.vault);
    assertEq(first.market, second.market);
    assertEq(first.hooks, second.hooks);
    assertEq(first.provider, second.provider);
    assertEq(first.oracle, second.oracle);
    assertEq(first.manifestHash, second.manifestHash);
  }

  function testPlannerProducesExactSingletonAndFixedTermInputs() external view {
    address lender = address(0xBEEF);
    bytes memory constructorArgs = BRCDeploymentLib.hooksConstructorArgs(manifest, lender);
    SingletonFixedTermHooksInputs memory inputs =
      abi.decode(constructorArgs, (SingletonFixedTermHooksInputs));
    NameAndProviderInputs memory access = inputs.accessControlInputs;
    assertEq(inputs.lender, lender);
    assertEq(access.roleProviderFactory, address(providerFactory));
    assertEq(access.newProviderInputs.length, 1);
    assertEq(access.existingProviders.length, 0);
    assertEq(access.newProviderInputs[0].timeToLive, 0);
    SingletonRoleProviderFactoryInputs memory providerInputs = abi.decode(
      access.newProviderInputs[0].providerFactoryCalldata, (SingletonRoleProviderFactoryInputs)
    );
    assertEq(providerInputs.lender, lender);
    assertEq(providerInputs.salt, manifest.hooks.providerSalt);

    bytes memory data = BRCDeploymentLib.hooksData(manifest);
    assertEq(data.length, 160);
    (
      uint32 fixedTermEndTime,
      uint128 minimumDeposit,
      bool transfersDisabled,
      bool allowClosureBeforeTerm,
      bool allowTermReduction
    ) = abi.decode(data, (uint32, uint128, bool, bool, bool));
    assertEq(fixedTermEndTime, manifest.oracle.maturity);
    assertEq(minimumDeposit, 0);
    assertTrue(transfersDisabled);
    assertFalse(allowClosureBeforeTerm);
    assertFalse(allowTermReduction);

    DeployMarketInputs memory marketInputs = BRCDeploymentLib.marketInputs(manifest);
    assertTrue(marketInputs.hooks.useOnDeposit());
    assertTrue(marketInputs.hooks.useOnTransfer());
    assertFalse(marketInputs.hooks.useOnQueueWithdrawal());
  }

  function testChangedPrincipalNonceRevertsBeforeVaultOrMarketDeployment() external {
    bytes32 manifestHash = BRCDeploymentLib.hashManifest(manifest);
    address expectedMarket = BRCDeploymentLib.marketAddress(manifest);
    address expectedVault = BRCDeploymentLib.vaultAddress(manifest, manifestHash, expectedMarket);

    hooksFactory.deployHooksInstance(
      manifest.hooks.template, BRCDeploymentLib.hooksConstructorArgs(manifest, address(0xBAD))
    );

    address expectedHooks = BRCDeploymentLib.hooksAddress(manifest, expectedVault);
    BRCAtomicDeployment memory input = BRCDeploymentLib.atomicDeploymentInputs(
      manifest, manifestHash, expectedVault, expectedMarket, expectedHooks
    );
    vm.expectRevert(
      abi.encodeWithSelector(BRCBorrowerAccount.DeploymentMismatch.selector, "hooksNonce")
    );
    borrowerAccount.deploySeries(input);
    assertEq(expectedVault.code.length, 0);
    assertEq(expectedMarket.code.length, 0);
  }

  function testChangedTemplateFeesRevertBeforeVaultOrMarketDeployment() external {
    bytes32 manifestHash = BRCDeploymentLib.hashManifest(manifest);
    address expectedMarket = BRCDeploymentLib.marketAddress(manifest);
    address expectedVault = BRCDeploymentLib.vaultAddress(manifest, manifestHash, expectedMarket);
    address expectedHooks = BRCDeploymentLib.hooksAddress(manifest, expectedVault);
    BRCAtomicDeployment memory input = BRCDeploymentLib.atomicDeploymentInputs(
      manifest, manifestHash, expectedVault, expectedMarket, expectedHooks
    );

    hooksFactory.updateHooksTemplateFees(
      manifest.hooks.template, address(0xFEE), address(0), 0, 100
    );

    vm.expectRevert(
      abi.encodeWithSelector(BRCBorrowerAccount.DeploymentMismatch.selector, "feeRecipient")
    );
    borrowerAccount.deploySeries(input);
    assertEq(expectedVault.code.length, 0);
    assertEq(expectedMarket.code.length, 0);
  }

  function testCounterfeitVaultInitcodeCannotUseApprovedAddress() external {
    bytes32 manifestHash = BRCDeploymentLib.hashManifest(manifest);
    address expectedMarket = BRCDeploymentLib.marketAddress(manifest);
    address expectedVault = BRCDeploymentLib.vaultAddress(manifest, manifestHash, expectedMarket);
    address expectedHooks = BRCDeploymentLib.hooksAddress(manifest, expectedVault);
    BRCAtomicDeployment memory input = BRCDeploymentLib.atomicDeploymentInputs(
      manifest, manifestHash, expectedVault, expectedMarket, expectedHooks
    );
    input.vaultInitCode = bytes.concat(input.vaultInitCode, hex"00");

    vm.expectRevert(abi.encodeWithSelector(BRCBorrowerAccount.DeploymentMismatch.selector, "vault"));
    borrowerAccount.deploySeries(input);
    assertEq(expectedVault.code.length, 0);
    assertEq(expectedMarket.code.length, 0);
  }

  function testOutsiderCannotConsumeBorrowerVaultSalt() external {
    bytes32 manifestHash = BRCDeploymentLib.hashManifest(manifest);
    address expectedMarket = BRCDeploymentLib.marketAddress(manifest);
    bytes memory initCode = BRCDeploymentLib.vaultInitCode(manifest, manifestHash, expectedMarket);
    vm.expectRevert(BRCVaultFactory.SaltDoesNotContainSender.selector);
    vaultFactory.deploy(manifest.vault.salt, initCode);
  }

  function testOnlyPrincipalCanRunAtomicDeployment() external {
    bytes32 manifestHash = BRCDeploymentLib.hashManifest(manifest);
    address expectedMarket = BRCDeploymentLib.marketAddress(manifest);
    address expectedVault = BRCDeploymentLib.vaultAddress(manifest, manifestHash, expectedMarket);
    address expectedHooks = BRCDeploymentLib.hooksAddress(manifest, expectedVault);
    BRCAtomicDeployment memory input = BRCDeploymentLib.atomicDeploymentInputs(
      manifest, manifestHash, expectedVault, expectedMarket, expectedHooks
    );
    vm.prank(address(0xBAD));
    vm.expectRevert(BRCBorrowerAccount.CallerNotPrincipal.selector);
    borrowerAccount.deploySeries(input);
  }

  function testJsonParserRejectsIntegerNarrowing() external {
    BRCJsonHarness harness = new BRCJsonHarness();
    string memory json = vm.readFile("config/series.example.json");
    json = vm.replace(json, "\"optimizerRuns\": 200", "\"optimizerRuns\": 4294967296");
    vm.expectRevert(
      abi.encodeWithSelector(BRCJson.JsonValueOutOfRange.selector, ".build.optimizerRuns")
    );
    harness.parse(json);
  }

  function testVerifierRejectsEveryDeploymentRecordMutation() external {
    BRCDeploymentRecord memory record = _deploy(manifest);

    bytes memory originalEncoding = record.encodedManifest;
    record.encodedManifest = bytes.concat(originalEncoding, hex"00");
    _reject(manifest, record, "record.encodedManifest");
    record.encodedManifest = originalEncoding;
    bytes32 originalHash = record.manifestHash;
    record.manifestHash = bytes32(uint256(originalHash) ^ 1);
    _reject(manifest, record, "record.manifestHash");
    record.manifestHash = originalHash;
    address original = record.vault;
    record.vault = address(1);
    _reject(manifest, record, "record.vault");
    record.vault = original;
    original = record.market;
    record.market = address(1);
    _reject(manifest, record, "record.market");
    record.market = original;
    original = record.hooks;
    record.hooks = address(1);
    _reject(manifest, record, "record.hooks");
    record.hooks = original;
    original = record.provider;
    record.provider = address(1);
    _reject(manifest, record, "record.provider");
    record.provider = original;
    original = record.oracle;
    record.oracle = address(1);
    _reject(manifest, record, "record.oracle");
    record.oracle = original;

    bytes32 originalCodeHash = record.vaultCodeHash;
    record.vaultCodeHash = bytes32(uint256(originalCodeHash) ^ 1);
    _reject(manifest, record, "record.vaultCodeHash");
    record.vaultCodeHash = originalCodeHash;
    originalCodeHash = record.marketCodeHash;
    record.marketCodeHash = bytes32(uint256(originalCodeHash) ^ 1);
    _reject(manifest, record, "record.marketCodeHash");
    record.marketCodeHash = originalCodeHash;
    originalCodeHash = record.hooksCodeHash;
    record.hooksCodeHash = bytes32(uint256(originalCodeHash) ^ 1);
    _reject(manifest, record, "record.hooksCodeHash");
    record.hooksCodeHash = originalCodeHash;
    originalCodeHash = record.providerCodeHash;
    record.providerCodeHash = bytes32(uint256(originalCodeHash) ^ 1);
    _reject(manifest, record, "record.providerCodeHash");
    record.providerCodeHash = originalCodeHash;
    originalCodeHash = record.oracleCodeHash;
    record.oracleCodeHash = bytes32(uint256(originalCodeHash) ^ 1);
    _reject(manifest, record, "record.oracleCodeHash");
  }

  function testVerifierRejectsMutationOfEveryManifestField() external {
    BRCDeploymentRecord memory record = _deploy(manifest);
    BRCSeriesManifest memory changed = manifest;

    changed.build.chainId += 1;
    _rejectAny(changed, record);
    changed.build.chainId -= 1;
    changed.build.environment = "changed";
    _rejectAny(changed, record);
    changed.build.environment = manifest.build.environment;
    changed.build.brcResearchCommit = "changed";
    _rejectAny(changed, record);
    changed.build.brcResearchCommit = manifest.build.brcResearchCommit;
    changed.build.v2ProtocolCommit = "changed";
    _rejectAny(changed, record);
    changed.build.v2ProtocolCommit = manifest.build.v2ProtocolCommit;
    changed.build.compilerVersion = "changed";
    _rejectAny(changed, record);
    changed.build.compilerVersion = manifest.build.compilerVersion;
    changed.build.evmVersion = "changed";
    _rejectAny(changed, record);
    changed.build.evmVersion = manifest.build.evmVersion;
    changed.build.optimizer = false;
    _rejectAny(changed, record);
    changed.build.optimizer = true;
    changed.build.optimizerRuns += 1;
    _rejectAny(changed, record);
    changed.build.optimizerRuns -= 1;
    changed.build.viaIR = false;
    _rejectAny(changed, record);
    changed.build.viaIR = true;
    changed.build.bytecodeHash = "changed";
    _rejectAny(changed, record);
    changed.build.bytecodeHash = manifest.build.bytecodeHash;

    changed.vault.name = "changed";
    _rejectAny(changed, record);
    changed.vault.name = manifest.vault.name;
    changed.vault.symbol = "changed";
    _rejectAny(changed, record);
    changed.vault.symbol = manifest.vault.symbol;
    changed.vault.accessController = address(1);
    _rejectAny(changed, record);
    changed.vault.accessController = manifest.vault.accessController;
    changed.vault.transfersRestricted = false;
    _rejectAny(changed, record);
    changed.vault.transfersRestricted = true;
    changed.vault.notional += 1;
    _rejectAny(changed, record);
    changed.vault.notional -= 1;
    changed.vault.minimumRaise -= 1;
    _rejectAny(changed, record);
    changed.vault.minimumRaise += 1;
    changed.vault.fundingDeadline += 1;
    _rejectAny(changed, record);
    changed.vault.fundingDeadline -= 1;
    changed.vault.activationDeadline += 1;
    _rejectAny(changed, record);
    changed.vault.activationDeadline -= 1;
    changed.vault.factory = address(1);
    _rejectAny(changed, record);
    changed.vault.factory = manifest.vault.factory;
    changed.vault.factoryCodeHash = bytes32(uint256(changed.vault.factoryCodeHash) ^ 1);
    _rejectAny(changed, record);
    changed.vault.factoryCodeHash = manifest.vault.factoryCodeHash;
    changed.vault.salt = bytes32(uint256(changed.vault.salt) ^ 1);
    _rejectAny(changed, record);
    changed.vault.salt = manifest.vault.salt;

    _rejectEveryMarketMutation(changed, record);
    _rejectEveryHooksMutation(changed, record);
    _rejectEveryOracleMutation(changed, record);
    _rejectEveryGovernanceMutation(changed, record);
  }

  function _rejectEveryMarketMutation(
    BRCSeriesManifest memory changed,
    BRCDeploymentRecord memory record
  ) private {
    address savedAddress = changed.market.borrower;
    changed.market.borrower = address(1);
    _rejectAny(changed, record);
    changed.market.borrower = savedAddress;
    bytes32 savedBytes32 = changed.market.borrowerCodeHash;
    changed.market.borrowerCodeHash = bytes32(uint256(savedBytes32) ^ 1);
    _rejectAny(changed, record);
    changed.market.borrowerCodeHash = savedBytes32;
    savedAddress = changed.market.borrowerPrincipal;
    changed.market.borrowerPrincipal = address(1);
    _rejectAny(changed, record);
    changed.market.borrowerPrincipal = savedAddress;
    savedAddress = changed.market.borrowerIdentityRegistry;
    changed.market.borrowerIdentityRegistry = address(1);
    _rejectAny(changed, record);
    changed.market.borrowerIdentityRegistry = savedAddress;
    savedBytes32 = changed.market.borrowerIdentityRegistryCodeHash;
    changed.market.borrowerIdentityRegistryCodeHash = bytes32(uint256(savedBytes32) ^ 1);
    _rejectAny(changed, record);
    changed.market.borrowerIdentityRegistryCodeHash = savedBytes32;
    savedAddress = changed.market.hooksFactory;
    changed.market.hooksFactory = address(1);
    _rejectAny(changed, record);
    changed.market.hooksFactory = savedAddress;
    savedBytes32 = changed.market.hooksFactoryCodeHash;
    changed.market.hooksFactoryCodeHash = bytes32(uint256(savedBytes32) ^ 1);
    _rejectAny(changed, record);
    changed.market.hooksFactoryCodeHash = savedBytes32;
    savedBytes32 = changed.market.marketSalt;
    changed.market.marketSalt = bytes32(uint256(savedBytes32) ^ 1);
    _rejectAny(changed, record);
    changed.market.marketSalt = savedBytes32;
    savedAddress = changed.market.settlementAsset;
    changed.market.settlementAsset = address(1);
    _rejectAny(changed, record);
    changed.market.settlementAsset = savedAddress;
    changed.market.namePrefix = "changed";
    _rejectAny(changed, record);
    changed.market.namePrefix = manifest.market.namePrefix;
    changed.market.symbolPrefix = "changed";
    _rejectAny(changed, record);
    changed.market.symbolPrefix = manifest.market.symbolPrefix;
    changed.market.marketCap += 1;
    _rejectAny(changed, record);
    changed.market.marketCap -= 1;
    changed.market.annualInterestBips += 1;
    _rejectAny(changed, record);
    changed.market.annualInterestBips -= 1;
    changed.market.reserveRatioBips += 1;
    _rejectAny(changed, record);
    changed.market.reserveRatioBips -= 1;
    changed.market.delinquencyFeeBips += 1;
    _rejectAny(changed, record);
    changed.market.delinquencyFeeBips -= 1;
    changed.market.delinquencyGracePeriod += 1;
    _rejectAny(changed, record);
    changed.market.delinquencyGracePeriod -= 1;
    changed.market.withdrawalBatchDuration += 1;
    _rejectAny(changed, record);
    changed.market.withdrawalBatchDuration -= 1;
    savedAddress = changed.market.feeRecipient;
    changed.market.feeRecipient = address(1);
    _rejectAny(changed, record);
    changed.market.feeRecipient = savedAddress;
    changed.market.protocolFeeBips += 1;
    _rejectAny(changed, record);
    changed.market.protocolFeeBips -= 1;
    changed.market.originationFeeAsset = address(1);
    _rejectAny(changed, record);
    changed.market.originationFeeAsset = address(0);
    changed.market.originationFeeAmount += 1;
    _rejectAny(changed, record);
    changed.market.originationFeeAmount -= 1;
    changed.market.recoveryDelay += 1;
    _rejectAny(changed, record);
    changed.market.recoveryDelay -= 1;
    changed.market.writeOffDelay += 1;
    _rejectAny(changed, record);
    changed.market.writeOffDelay -= 1;
  }

  function _rejectEveryHooksMutation(
    BRCSeriesManifest memory changed,
    BRCDeploymentRecord memory record
  ) private {
    address savedAddress = changed.hooks.template;
    changed.hooks.template = address(1);
    _rejectAny(changed, record);
    changed.hooks.template = savedAddress;
    bytes32 savedBytes32 = changed.hooks.templateCodeHash;
    changed.hooks.templateCodeHash = bytes32(uint256(savedBytes32) ^ 1);
    _rejectAny(changed, record);
    changed.hooks.templateCodeHash = savedBytes32;
    savedAddress = changed.hooks.providerFactory;
    changed.hooks.providerFactory = address(1);
    _rejectAny(changed, record);
    changed.hooks.providerFactory = savedAddress;
    savedBytes32 = changed.hooks.providerFactoryCodeHash;
    changed.hooks.providerFactoryCodeHash = bytes32(uint256(savedBytes32) ^ 1);
    _rejectAny(changed, record);
    changed.hooks.providerFactoryCodeHash = savedBytes32;
    changed.hooks.providerSalt = bytes32(uint256(changed.hooks.providerSalt) ^ 1);
    _rejectAny(changed, record);
    changed.hooks.providerSalt = manifest.hooks.providerSalt;
    changed.hooks.deploymentNonce += 1;
    _rejectAny(changed, record);
    changed.hooks.deploymentNonce -= 1;
    changed.hooks.name = "changed";
    _rejectAny(changed, record);
    changed.hooks.name = manifest.hooks.name;
  }

  function _rejectEveryOracleMutation(
    BRCSeriesManifest memory changed,
    BRCDeploymentRecord memory record
  ) private {
    address savedAddress = changed.oracle.btcUsdFeed;
    changed.oracle.btcUsdFeed = address(1);
    _rejectAny(changed, record);
    changed.oracle.btcUsdFeed = savedAddress;
    bytes32 savedBytes32 = changed.oracle.feedCodeHash;
    changed.oracle.feedCodeHash = bytes32(uint256(savedBytes32) ^ 1);
    _rejectAny(changed, record);
    changed.oracle.feedCodeHash = savedBytes32;
    changed.oracle.feedDecimals += 1;
    _rejectAny(changed, record);
    changed.oracle.feedDecimals -= 1;
    savedBytes32 = changed.oracle.feedDescriptionHash;
    changed.oracle.feedDescriptionHash = bytes32(uint256(savedBytes32) ^ 1);
    _rejectAny(changed, record);
    changed.oracle.feedDescriptionHash = savedBytes32;
    changed.oracle.maxInitialAge += 1;
    _rejectAny(changed, record);
    changed.oracle.maxInitialAge -= 1;
    changed.oracle.maxFutureSkew += 1;
    _rejectAny(changed, record);
    changed.oracle.maxFutureSkew -= 1;
    changed.oracle.strikeAtInitialFixing = false;
    _rejectAny(changed, record);
    changed.oracle.strikeAtInitialFixing = true;
    changed.oracle.barrierObservedOnlyAtMaturity = false;
    _rejectAny(changed, record);
    changed.oracle.barrierObservedOnlyAtMaturity = true;
    changed.oracle.barrierBips += 1;
    _rejectAny(changed, record);
    changed.oracle.barrierBips -= 1;
    changed.oracle.maturity += 1;
    _rejectAny(changed, record);
    changed.oracle.maturity -= 1;
    changed.oracle.maxObservationDelay += 1;
    _rejectAny(changed, record);
    changed.oracle.maxObservationDelay -= 1;
    savedAddress = changed.oracle.fallbackRatifiers[0];
    changed.oracle.fallbackRatifiers[0] = address(1);
    _rejectAny(changed, record);
    changed.oracle.fallbackRatifiers[0] = savedAddress;
    changed.oracle.fallbackThreshold -= 1;
    _rejectAny(changed, record);
    changed.oracle.fallbackThreshold += 1;
    changed.oracle.fallbackWaitingPeriod += 1;
    _rejectAny(changed, record);
    changed.oracle.fallbackWaitingPeriod -= 1;
    changed.oracle.fallbackChallengePeriod += 1;
    _rejectAny(changed, record);
    changed.oracle.fallbackChallengePeriod -= 1;
    changed.oracle.fallbackSourceId = bytes32(uint256(changed.oracle.fallbackSourceId) ^ 1);
    _rejectAny(changed, record);
    changed.oracle.fallbackSourceId = manifest.oracle.fallbackSourceId;
  }

  function _rejectEveryGovernanceMutation(
    BRCSeriesManifest memory changed,
    BRCDeploymentRecord memory record
  ) private {
    address savedAddress = changed.governance.archController;
    changed.governance.archController = address(1);
    _rejectAny(changed, record);
    changed.governance.archController = savedAddress;
    savedAddress = changed.governance.archControllerOwner;
    changed.governance.archControllerOwner = address(1);
    _rejectAny(changed, record);
    changed.governance.archControllerOwner = savedAddress;
    savedAddress = changed.governance.sphereXAdmin;
    changed.governance.sphereXAdmin = address(1);
    _rejectAny(changed, record);
    changed.governance.sphereXAdmin = savedAddress;
    changed.governance.pendingSphereXAdmin = address(1);
    _rejectAny(changed, record);
    changed.governance.pendingSphereXAdmin = address(0);
    changed.governance.sphereXOperator = address(1);
    _rejectAny(changed, record);
    changed.governance.sphereXOperator = address(0);
    changed.governance.sphereXEngine = address(1);
    _rejectAny(changed, record);
    changed.governance.sphereXEngine = address(0);
    changed.governance.sphereXEngineMutable = false;
    _rejectAny(changed, record);
  }

  function _deploy(BRCSeriesManifest memory terms)
    private
    returns (BRCDeploymentRecord memory record)
  {
    BRCDeploymentLib.validatePredeployment(terms);
    address expectedMarket = BRCDeploymentLib.marketAddress(terms);
    bytes32 manifestHash = BRCDeploymentLib.hashManifest(terms);
    address expectedVault = BRCDeploymentLib.vaultAddress(terms, manifestHash, expectedMarket);
    address expectedHooks = BRCDeploymentLib.hooksAddress(terms, expectedVault);
    BRCAtomicDeployment memory input = BRCDeploymentLib.atomicDeploymentInputs(
      terms, manifestHash, expectedVault, expectedMarket, expectedHooks
    );
    (address vaultAddress, address market, address hooks) = borrowerAccount.deploySeries(input);
    BRCNoteVault vault = BRCNoteVault(vaultAddress);
    assertEq(address(vault), expectedVault);
    assertEq(market, expectedMarket);
    assertEq(hooks, expectedHooks);
    address provider = BRCDeploymentLib.providerAddress(terms, hooks, address(vault));
    record = BRCDeploymentRecord({
      encodedManifest: abi.encode(terms),
      manifestHash: manifestHash,
      vault: address(vault),
      market: market,
      hooks: hooks,
      provider: provider,
      oracle: address(vault.fixingOracle()),
      vaultCodeHash: address(vault).codehash,
      marketCodeHash: market.codehash,
      hooksCodeHash: hooks.codehash,
      providerCodeHash: provider.codehash,
      oracleCodeHash: address(vault.fixingOracle()).codehash
    });
  }

  function _manifest() private view returns (BRCSeriesManifest memory value) {
    address[] memory ratifiers = new address[](3);
    ratifiers[0] = address(0xA11CE);
    ratifiers[1] = address(0xB0B);
    ratifiers[2] = address(0xCAFE);
    uint40 fundingDeadline = uint40(block.timestamp + 7 days);
    uint40 activationDeadline = uint40(block.timestamp + 14 days);
    uint40 maturity = uint40(block.timestamp + 90 days);
    value.build = BRCBuildManifest({
      chainId: block.chainid,
      environment: "local",
      brcResearchCommit: "PR10",
      v2ProtocolCommit: "99bb85840a77a56fa5f64504a60ec126b6047cf5",
      compilerVersion: "0.8.28",
      evmVersion: "cancun",
      optimizer: true,
      optimizerRuns: 200,
      viaIR: true,
      bytecodeHash: "none"
    });
    value.vault = BRCVaultManifest({
      name: "Wildcat BTC BRC Note",
      symbol: "wcBRC-BTC",
      accessController: address(this),
      transfersRestricted: true,
      notional: NOTIONAL,
      minimumRaise: NOTIONAL,
      fundingDeadline: fundingDeadline,
      activationDeadline: activationDeadline,
      factory: address(vaultFactory),
      factoryCodeHash: address(vaultFactory).codehash,
      salt: bytes32((uint256(uint160(address(borrowerAccount))) << 96) | uint256(9))
    });
    value.market = BRCMarketManifest({
      borrower: address(borrowerAccount),
      borrowerCodeHash: address(borrowerAccount).codehash,
      borrowerPrincipal: address(this),
      borrowerIdentityRegistry: address(borrowerRegistry),
      borrowerIdentityRegistryCodeHash: address(borrowerRegistry).codehash,
      hooksFactory: address(hooksFactory),
      hooksFactoryCodeHash: address(hooksFactory).codehash,
      marketSalt: bytes32((uint256(uint160(address(borrowerAccount))) << 96) | uint256(10)),
      settlementAsset: address(asset),
      namePrefix: "Wildcat ",
      symbolPrefix: "WC",
      marketCap: NOTIONAL,
      annualInterestBips: 1_200,
      reserveRatioBips: 1_000,
      delinquencyFeeBips: 0,
      delinquencyGracePeriod: 1 days,
      withdrawalBatchDuration: 1 days,
      feeRecipient: address(0),
      protocolFeeBips: 0,
      originationFeeAsset: address(0),
      originationFeeAmount: 0,
      recoveryDelay: 2 days,
      writeOffDelay: 30 days
    });
    value.hooks = BRCHooksManifest({
      template: hooksTemplate,
      templateCodeHash: hooksTemplate.codehash,
      providerFactory: address(providerFactory),
      providerFactoryCodeHash: address(providerFactory).codehash,
      providerSalt: keccak256("brc-provider"),
      deploymentNonce: hooksFactory.getHooksInstanceDeploymentNonce(address(this)),
      name: "BRC singleton lender"
    });
    value.oracle = BRCOracleManifest({
      btcUsdFeed: address(feed),
      feedCodeHash: address(feed).codehash,
      feedDecimals: 8,
      feedDescriptionHash: DESCRIPTION_HASH,
      maxInitialAge: 1 hours,
      maxFutureSkew: 30 seconds,
      strikeAtInitialFixing: true,
      barrierObservedOnlyAtMaturity: true,
      barrierBips: 6_000,
      maturity: maturity,
      maxObservationDelay: 1 hours,
      fallbackRatifiers: ratifiers,
      fallbackThreshold: 2,
      fallbackWaitingPeriod: 1 days,
      fallbackChallengePeriod: 1 days,
      fallbackSourceId: keccak256("BTC fallback")
    });
    value.governance = BRCGovernanceManifest({
      archController: address(archController),
      archControllerOwner: archController.owner(),
      sphereXAdmin: archController.sphereXAdmin(),
      pendingSphereXAdmin: archController.pendingSphereXAdmin(),
      sphereXOperator: archController.sphereXOperator(),
      sphereXEngine: archController.sphereXEngine(),
      sphereXEngineMutable: true
    });
  }

  function _reject(
    BRCSeriesManifest memory terms,
    BRCDeploymentRecord memory record,
    string memory field
  ) private {
    vm.expectRevert(
      abi.encodeWithSelector(BRCDeploymentVerifier.DeploymentMismatch.selector, field)
    );
    verifier.verify(terms, record);
  }

  function _rejectAny(BRCSeriesManifest memory terms, BRCDeploymentRecord memory record) private {
    vm.expectRevert();
    verifier.verify(terms, record);
  }
}

contract BRCDeploymentMainnetForkTest is Test {
  address internal constant BTC_USD_FEED = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
  bytes32 internal constant BTC_USD_DESCRIPTION_HASH = keccak256("BTC / USD");

  function testMainnetForkUsesPinnedFactoryArtifactAndLiveFeed() external {
    string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
    if (bytes(rpcUrl).length == 0) {
      vm.skip(true);
    }
    vm.createSelectFork(rpcUrl);

    assertGt(BTC_USD_FEED.code.length, 0);
    assertEq(MockChainlinkProxy(BTC_USD_FEED).decimals(), 8);
    assertEq(
      keccak256(bytes(MockChainlinkProxy(BTC_USD_FEED).description())), BTC_USD_DESCRIPTION_HASH
    );

    WildcatArchController archController = new WildcatArchController();
    WildcatBorrowerIdentityRegistry borrowerRegistry =
      new WildcatBorrowerIdentityRegistry(address(archController));
    WildcatSanctionsSentinel sanctionsSentinel =
      new WildcatSanctionsSentinel(address(archController), address(new MockChainalysis()));
    Wildcat4626WrapperFactory wrapperFactory =
      new Wildcat4626WrapperFactory(address(archController), address(0));
    address marketInitCode = LibStoredInitCode.deployInitCode(type(WildcatMarket).creationCode);
    HooksFactory forkFactory = new HooksFactory(
      address(archController),
      address(sanctionsSentinel),
      address(wrapperFactory),
      marketInitCode,
      uint256(keccak256(type(WildcatMarket).creationCode)),
      address(borrowerRegistry)
    );
    address template = LibStoredInitCode.deployInitCode(type(SingletonFixedTermHooks).creationCode);
    archController.registerControllerFactory(address(forkFactory));
    forkFactory.registerWithArchController();
    forkFactory.addHooksTemplate(template, "SingletonFixedTermHooks", address(0), address(0), 0, 0);

    assertGt(address(forkFactory).code.length, 0);
    assertGt(template.code.length, 1);
    assertTrue(forkFactory.isHooksTemplate(template));
  }
}
