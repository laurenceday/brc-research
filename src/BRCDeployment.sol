// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {
  ActivationTerms,
  BRCNoteVault,
  IHooksFactoryView,
  IWildcatActivationMarket
} from "./BRCNoteVault.sol";
import { BRCFallbackConfig } from "./BRCFallback.sol";
import { BRCAtomicDeployment } from "./BRCBorrowerAccount.sol";
import { BtcUsdFixingOracle } from "./BtcUsdFixingOracle.sol";
import { BRCVaultFactory } from "./BRCVaultFactory.sol";
import { AggregatorV3Interface } from "./interfaces/AggregatorV3Interface.sol";
import { IERC20Metadata } from "./interfaces/IERC20.sol";
import { FixedTermHooks, HookedMarket } from "v2-protocol/access/FixedTermHooks.sol";
import { SingletonFixedTermHooksInputs } from "v2-protocol/access/SingletonFixedTermHooks.sol";
import {
  CreateProviderInputs,
  NameAndProviderInputs
} from "v2-protocol/access/ProviderStructs.sol";
import { HooksTemplate } from "v2-protocol/IHooksFactory.sol";
import { IBorrowerIdentityRegistry } from "v2-protocol/interfaces/IBorrowerIdentityRegistry.sol";
import {
  ISphereXProtectedRegisteredBase
} from "v2-protocol/interfaces/ISphereXProtectedRegisteredBase.sol";
import { IWildcatArchController } from "v2-protocol/interfaces/IWildcatArchController.sol";
import { DeployMarketInputs } from "v2-protocol/interfaces/WildcatStructsAndEnums.sol";
import { MarketState } from "v2-protocol/libraries/MarketState.sol";
import {
  ISingletonRoleProviderFactory,
  SingletonRoleProviderFactoryInputs
} from "v2-protocol/providers/ISingletonRoleProviderFactory.sol";
import { ISingletonRoleProvider } from "v2-protocol/providers/ISingletonRoleProvider.sol";
import { encodeHooksConfig, HooksConfig, LibHooksConfig } from "v2-protocol/types/HooksConfig.sol";
import { LibRoleProvider, RoleProvider } from "v2-protocol/types/RoleProvider.sol";

using LibHooksConfig for HooksConfig;
using LibRoleProvider for RoleProvider;

struct BRCBuildManifest {
  uint256 chainId;
  string environment;
  string brcResearchCommit;
  string v2ProtocolCommit;
  string compilerVersion;
  string evmVersion;
  bool optimizer;
  uint32 optimizerRuns;
  bool viaIR;
  string bytecodeHash;
}

struct BRCVaultManifest {
  string name;
  string symbol;
  address accessController;
  bool transfersRestricted;
  uint128 notional;
  uint128 minimumRaise;
  uint40 fundingDeadline;
  uint40 activationDeadline;
  address factory;
  bytes32 factoryCodeHash;
  bytes32 salt;
}

struct BRCMarketManifest {
  address borrower;
  bytes32 borrowerCodeHash;
  address borrowerPrincipal;
  address borrowerIdentityRegistry;
  bytes32 borrowerIdentityRegistryCodeHash;
  address hooksFactory;
  bytes32 hooksFactoryCodeHash;
  bytes32 marketSalt;
  address settlementAsset;
  string namePrefix;
  string symbolPrefix;
  uint128 marketCap;
  uint16 annualInterestBips;
  uint16 reserveRatioBips;
  uint16 delinquencyFeeBips;
  uint32 delinquencyGracePeriod;
  uint32 withdrawalBatchDuration;
  address feeRecipient;
  uint16 protocolFeeBips;
  address originationFeeAsset;
  uint80 originationFeeAmount;
  uint32 recoveryDelay;
  uint32 writeOffDelay;
}

struct BRCHooksManifest {
  address template;
  bytes32 templateCodeHash;
  address providerFactory;
  bytes32 providerFactoryCodeHash;
  bytes32 providerSalt;
  uint256 deploymentNonce;
  string name;
}

struct BRCOracleManifest {
  address btcUsdFeed;
  bytes32 feedCodeHash;
  uint8 feedDecimals;
  bytes32 feedDescriptionHash;
  uint32 maxInitialAge;
  uint32 maxFutureSkew;
  bool strikeAtInitialFixing;
  bool barrierObservedOnlyAtMaturity;
  uint16 barrierBips;
  uint40 maturity;
  uint32 maxObservationDelay;
  address[] fallbackRatifiers;
  uint8 fallbackThreshold;
  uint32 fallbackWaitingPeriod;
  uint32 fallbackChallengePeriod;
  bytes32 fallbackSourceId;
}

struct BRCGovernanceManifest {
  address archController;
  address archControllerOwner;
  address sphereXAdmin;
  address pendingSphereXAdmin;
  address sphereXOperator;
  address sphereXEngine;
  bool sphereXEngineMutable;
}

struct BRCSeriesManifest {
  BRCBuildManifest build;
  BRCVaultManifest vault;
  BRCMarketManifest market;
  BRCHooksManifest hooks;
  BRCOracleManifest oracle;
  BRCGovernanceManifest governance;
}

struct BRCDeploymentRecord {
  bytes encodedManifest;
  bytes32 manifestHash;
  address vault;
  address market;
  address hooks;
  address provider;
  address oracle;
  bytes32 vaultCodeHash;
  bytes32 marketCodeHash;
  bytes32 hooksCodeHash;
  bytes32 providerCodeHash;
  bytes32 oracleCodeHash;
}

interface IHooksDeploymentFactory is IHooksFactoryView {
  function archController() external view returns (address);

  function borrowerIdentityRegistry() external view returns (address);

  function getHooksInstanceDeploymentNonce(address administrator) external view returns (uint256);

  function getHooksTemplateDetails(address hooksTemplate)
    external
    view
    returns (HooksTemplate memory);
}

interface IBRCVaultFactory {
  function deploy(bytes32 salt, bytes calldata initCode) external returns (address vault);

  function computeAddress(bytes32 salt, bytes32 initCodeHash) external view returns (address vault);
}

interface IBRCBorrowerAccountView {
  function registry() external view returns (IBorrowerIdentityRegistry);
}

library BRCDeploymentLib {
  error InvalidManifest(string field);

  function hashManifest(BRCSeriesManifest memory manifest) internal pure returns (bytes32) {
    return keccak256(abi.encode(manifest));
  }

  function validateManifest(BRCSeriesManifest memory manifest) internal view {
    _require(manifest.build.chainId == block.chainid, "build.chainId");
    _require(bytes(manifest.build.environment).length != 0, "build.environment");
    _require(bytes(manifest.build.brcResearchCommit).length != 0, "build.brcResearchCommit");
    _require(bytes(manifest.build.v2ProtocolCommit).length != 0, "build.v2ProtocolCommit");
    _require(bytes(manifest.build.compilerVersion).length != 0, "build.compilerVersion");
    _require(bytes(manifest.build.evmVersion).length != 0, "build.evmVersion");
    _require(manifest.build.optimizer, "build.optimizer");
    _require(manifest.build.optimizerRuns != 0, "build.optimizerRuns");
    _require(manifest.build.viaIR, "build.viaIR");
    _require(bytes(manifest.build.bytecodeHash).length != 0, "build.bytecodeHash");

    _require(manifest.vault.accessController != address(0), "vault.accessController");
    _require(bytes(manifest.vault.name).length != 0, "vault.name");
    _require(bytes(manifest.vault.symbol).length != 0, "vault.symbol");
    _require(manifest.vault.notional != 0, "vault.notional");
    _require(manifest.vault.minimumRaise == manifest.vault.notional, "vault.minimumRaise");
    _require(manifest.vault.fundingDeadline != 0, "vault.fundingDeadline");
    _require(
      manifest.vault.activationDeadline > manifest.vault.fundingDeadline, "vault.activationDeadline"
    );
    _require(manifest.vault.factory != address(0), "vault.factory");
    _require(manifest.vault.factoryCodeHash != bytes32(0), "vault.factoryCodeHash");

    _require(manifest.market.borrower != address(0), "market.borrower");
    _require(manifest.market.borrowerCodeHash != bytes32(0), "market.borrowerCodeHash");
    _require(manifest.market.borrowerPrincipal != address(0), "market.borrowerPrincipal");
    _require(
      manifest.market.borrowerIdentityRegistry != address(0), "market.borrowerIdentityRegistry"
    );
    _require(
      manifest.market.borrowerIdentityRegistryCodeHash != bytes32(0),
      "market.borrowerIdentityRegistryCodeHash"
    );
    _require(manifest.market.hooksFactory != address(0), "market.hooksFactory");
    _require(manifest.market.hooksFactoryCodeHash != bytes32(0), "market.hooksFactoryCodeHash");
    _require(manifest.market.settlementAsset != address(0), "market.settlementAsset");
    _require(manifest.market.marketCap == manifest.vault.notional, "market.marketCap");
    _require(bytes(manifest.market.namePrefix).length != 0, "market.namePrefix");
    _require(bytes(manifest.market.symbolPrefix).length != 0, "market.symbolPrefix");
    _require(
      address(bytes20(manifest.market.marketSalt)) == manifest.market.borrower, "market.marketSalt"
    );
    _require(address(bytes20(manifest.vault.salt)) == manifest.market.borrower, "vault.salt");
    _require(manifest.market.withdrawalBatchDuration != 0, "market.withdrawalBatchDuration");
    _require(
      manifest.market.recoveryDelay >= manifest.oracle.maxObservationDelay, "market.recoveryDelay"
    );
    _require(manifest.market.writeOffDelay != 0, "market.writeOffDelay");

    _require(manifest.hooks.template != address(0), "hooks.template");
    _require(manifest.hooks.templateCodeHash != bytes32(0), "hooks.templateCodeHash");
    _require(manifest.hooks.providerFactory != address(0), "hooks.providerFactory");
    _require(manifest.hooks.providerFactoryCodeHash != bytes32(0), "hooks.providerFactoryCodeHash");
    _require(bytes(manifest.hooks.name).length != 0, "hooks.name");
    _require(manifest.hooks.deploymentNonce <= type(uint96).max, "hooks.deploymentNonce");

    _require(manifest.oracle.btcUsdFeed != address(0), "oracle.btcUsdFeed");
    _require(manifest.oracle.feedCodeHash != bytes32(0), "oracle.feedCodeHash");
    _require(manifest.oracle.feedDescriptionHash != bytes32(0), "oracle.feedDescriptionHash");
    _require(manifest.oracle.strikeAtInitialFixing, "oracle.strikeAtInitialFixing");
    _require(manifest.oracle.barrierObservedOnlyAtMaturity, "oracle.barrierObservedOnlyAtMaturity");
    _require(manifest.oracle.maturity > manifest.vault.activationDeadline, "oracle.maturity");
    _require(
      manifest.oracle.fallbackRatifiers.length != 0
        && manifest.oracle.fallbackRatifiers.length <= 8,
      "oracle.fallbackRatifiers"
    );
    _require(
      manifest.oracle.fallbackThreshold != 0
        && manifest.oracle.fallbackThreshold <= manifest.oracle.fallbackRatifiers.length,
      "oracle.fallbackThreshold"
    );
    _require(manifest.oracle.fallbackWaitingPeriod != 0, "oracle.fallbackWaitingPeriod");
    _require(manifest.oracle.fallbackChallengePeriod != 0, "oracle.fallbackChallengePeriod");
    _require(manifest.oracle.fallbackSourceId != bytes32(0), "oracle.fallbackSourceId");
    for (uint256 i; i < manifest.oracle.fallbackRatifiers.length; i++) {
      address ratifier = manifest.oracle.fallbackRatifiers[i];
      _require(ratifier != address(0) && ratifier.code.length == 0, "oracle.fallbackRatifier");
      for (uint256 j; j < i; j++) {
        _require(ratifier != manifest.oracle.fallbackRatifiers[j], "oracle.fallbackRatifier");
      }
    }

    _require(manifest.governance.archController != address(0), "governance.archController");
    _require(
      manifest.governance.archControllerOwner != address(0), "governance.archControllerOwner"
    );
    _require(manifest.governance.sphereXAdmin != address(0), "governance.sphereXAdmin");
    _require(manifest.governance.sphereXEngineMutable, "governance.sphereXEngineMutable");

    _require(
      manifest.market.hooksFactory.codehash == manifest.market.hooksFactoryCodeHash,
      "market.hooksFactoryCodeHash"
    );
    _require(
      manifest.market.borrower.codehash == manifest.market.borrowerCodeHash,
      "market.borrowerCodeHash"
    );
    _require(
      manifest.market.borrowerIdentityRegistry.codehash
        == manifest.market.borrowerIdentityRegistryCodeHash,
      "market.borrowerIdentityRegistryCodeHash"
    );
    _require(
      address(IBRCBorrowerAccountView(manifest.market.borrower).registry())
        == manifest.market.borrowerIdentityRegistry,
      "market.borrowerRegistry"
    );
    _require(
      IHooksDeploymentFactory(manifest.market.hooksFactory).borrowerIdentityRegistry()
        == manifest.market.borrowerIdentityRegistry,
      "market.borrowerIdentityRegistry"
    );
    _require(
      IBorrowerIdentityRegistry(manifest.market.borrowerIdentityRegistry)
        .resolveBorrower(manifest.market.borrower) == manifest.market.borrowerPrincipal,
      "market.borrowerPrincipal"
    );
    _require(
      manifest.vault.factory.codehash == manifest.vault.factoryCodeHash, "vault.factoryCodeHash"
    );
    _require(
      manifest.vault.factoryCodeHash == keccak256(type(BRCVaultFactory).runtimeCode),
      "vault.factoryArtifact"
    );
    _require(
      manifest.hooks.template.codehash == manifest.hooks.templateCodeHash, "hooks.templateCodeHash"
    );
    _require(
      manifest.hooks.providerFactory.codehash == manifest.hooks.providerFactoryCodeHash,
      "hooks.providerFactoryCodeHash"
    );
    _require(
      manifest.oracle.btcUsdFeed.codehash == manifest.oracle.feedCodeHash, "oracle.feedCodeHash"
    );
    HooksTemplate memory template = IHooksDeploymentFactory(manifest.market.hooksFactory)
      .getHooksTemplateDetails(manifest.hooks.template);
    _require(template.exists && template.enabled, "hooks.templateEnabled");
    _require(template.feeRecipient == manifest.market.feeRecipient, "market.feeRecipient");
    _require(template.protocolFeeBips == manifest.market.protocolFeeBips, "market.protocolFeeBips");
    _require(
      template.originationFeeAsset == manifest.market.originationFeeAsset,
      "market.originationFeeAsset"
    );
    _require(
      template.originationFeeAmount == manifest.market.originationFeeAmount,
      "market.originationFeeAmount"
    );
    IWildcatArchController archController =
      IWildcatArchController(manifest.governance.archController);
    _require(
      IHooksDeploymentFactory(manifest.market.hooksFactory).archController()
        == manifest.governance.archController,
      "governance.archController"
    );
    _require(
      archController.owner() == manifest.governance.archControllerOwner,
      "governance.archControllerOwner"
    );
    _require(
      archController.sphereXAdmin() == manifest.governance.sphereXAdmin, "governance.sphereXAdmin"
    );
    _require(
      archController.pendingSphereXAdmin() == manifest.governance.pendingSphereXAdmin,
      "governance.pendingSphereXAdmin"
    );
    _require(
      archController.sphereXOperator() == manifest.governance.sphereXOperator,
      "governance.sphereXOperator"
    );
    _require(
      archController.sphereXEngine() == manifest.governance.sphereXEngine,
      "governance.sphereXEngine"
    );
    _require(
      ISphereXProtectedRegisteredBase(manifest.market.hooksFactory).sphereXOperator()
        == manifest.governance.archController,
      "governance.hooksFactorySphereXOperator"
    );
    _require(
      ISphereXProtectedRegisteredBase(manifest.market.hooksFactory).sphereXEngine()
        == manifest.governance.sphereXEngine,
      "governance.hooksFactorySphereXEngine"
    );
    _require(
      AggregatorV3Interface(manifest.oracle.btcUsdFeed).decimals() == manifest.oracle.feedDecimals,
      "oracle.feedDecimals"
    );
    _require(
      keccak256(bytes(AggregatorV3Interface(manifest.oracle.btcUsdFeed).description()))
        == manifest.oracle.feedDescriptionHash,
      "oracle.feedDescriptionHash"
    );
  }

  function validatePredeployment(BRCSeriesManifest memory manifest) internal view {
    validateManifest(manifest);
    _require(manifest.vault.fundingDeadline > block.timestamp, "vault.fundingDeadline");
    _require(
      IHooksDeploymentFactory(manifest.market.hooksFactory)
        .getHooksInstanceDeploymentNonce(manifest.market.borrowerPrincipal)
      == manifest.hooks.deploymentNonce,
      "hooks.deploymentNonce"
    );
  }

  function marketAddress(BRCSeriesManifest memory manifest) internal view returns (address) {
    return IHooksFactoryView(manifest.market.hooksFactory)
      .computeMarketAddress(manifest.market.marketSalt);
  }

  function createdAddress(address deployer, uint256 nonce) internal pure returns (address) {
    address deployed;
    assembly ("memory-safe") {
      for { } 1 { } {
        if iszero(gt(nonce, 0x7f)) {
          mstore(0x00, deployer)
          mstore8(0x0b, 0x94)
          mstore8(0x0a, 0xd6)
          mstore8(0x20, or(shl(7, iszero(nonce)), nonce))
          deployed := keccak256(0x0a, 0x17)
          break
        }
        let i := 8
        for { } shr(i, nonce) { i := add(i, 8) } { }
        i := shr(3, i)
        mstore(i, nonce)
        mstore(0x00, shl(8, deployer))
        mstore8(0x1f, add(0x80, i))
        mstore8(0x0a, 0x94)
        mstore8(0x09, add(0xd6, i))
        deployed := keccak256(0x09, add(0x17, i))
        break
      }
    }
    return deployed;
  }

  function vaultInitCode(
    BRCSeriesManifest memory manifest,
    bytes32 manifestHash,
    address expectedMarket
  ) internal pure returns (bytes memory) {
    ActivationTerms memory terms = activationTerms(manifest, manifestHash, expectedMarket);
    return abi.encodePacked(
      type(BRCNoteVault).creationCode,
      abi.encode(
        IERC20Metadata(manifest.market.settlementAsset),
        manifest.vault.accessController,
        manifest.vault.name,
        manifest.vault.symbol,
        manifest.vault.notional,
        manifest.vault.minimumRaise,
        manifest.vault.fundingDeadline,
        manifest.vault.transfersRestricted,
        terms
      )
    );
  }

  function vaultAddress(
    BRCSeriesManifest memory manifest,
    bytes32 manifestHash,
    address expectedMarket
  ) internal view returns (address) {
    bytes32 initCodeHash = keccak256(vaultInitCode(manifest, manifestHash, expectedMarket));
    return
      IBRCVaultFactory(manifest.vault.factory).computeAddress(manifest.vault.salt, initCodeHash);
  }

  function hooksAddress(BRCSeriesManifest memory manifest, address lender)
    internal
    view
    returns (address expected)
  {
    bytes memory constructorArgs = hooksConstructorArgs(manifest, lender);
    bytes memory encodedConstructor = abi.encode(manifest.market.borrowerPrincipal, constructorArgs);
    uint256 storedLength = manifest.hooks.template.code.length;
    _require(storedLength > 1, "hooks.templateCode");
    bytes memory initCode = new bytes(storedLength - 1 + encodedConstructor.length);
    address template = manifest.hooks.template;
    assembly ("memory-safe") {
      extcodecopy(template, add(initCode, 0x20), 1, sub(storedLength, 1))
    }
    uint256 offset = storedLength - 1;
    for (uint256 i; i < encodedConstructor.length; i++) {
      initCode[offset + i] = encodedConstructor[i];
    }
    bytes32 salt = bytes32(
      (uint256(uint160(manifest.market.borrowerPrincipal)) << 96) | manifest.hooks.deploymentNonce
    );
    expected = address(
      uint160(
        uint256(
          keccak256(
            abi.encodePacked(bytes1(0xff), manifest.market.hooksFactory, salt, keccak256(initCode))
          )
        )
      )
    );
  }

  function providerAddress(BRCSeriesManifest memory manifest, address hooks, address lender)
    internal
    view
    returns (address)
  {
    return ISingletonRoleProviderFactory(manifest.hooks.providerFactory)
      .computeRoleProviderAddress(
        hooks,
        SingletonRoleProviderFactoryInputs({ lender: lender, salt: manifest.hooks.providerSalt })
      );
  }

  function hooksConstructorArgs(BRCSeriesManifest memory manifest, address lender)
    internal
    pure
    returns (bytes memory)
  {
    SingletonRoleProviderFactoryInputs memory providerInputs =
      SingletonRoleProviderFactoryInputs({ lender: lender, salt: manifest.hooks.providerSalt });
    NameAndProviderInputs memory accessInputs;
    accessInputs.name = manifest.hooks.name;
    accessInputs.roleProviderFactory = manifest.hooks.providerFactory;
    accessInputs.newProviderInputs = new CreateProviderInputs[](1);
    accessInputs.newProviderInputs[0] =
      CreateProviderInputs({ timeToLive: 0, providerFactoryCalldata: abi.encode(providerInputs) });
    return abi.encode(SingletonFixedTermHooksInputs(accessInputs, lender));
  }

  function hooksData(BRCSeriesManifest memory manifest) internal pure returns (bytes memory data) {
    data = abi.encode(uint32(manifest.oracle.maturity), uint128(0), true, false, false);
    _require(data.length == 160, "hooks.dataLength");
  }

  function marketInputs(BRCSeriesManifest memory manifest)
    internal
    pure
    returns (DeployMarketInputs memory)
  {
    return DeployMarketInputs({
      asset: manifest.market.settlementAsset,
      namePrefix: manifest.market.namePrefix,
      symbolPrefix: manifest.market.symbolPrefix,
      maxTotalSupply: manifest.market.marketCap,
      annualInterestBips: manifest.market.annualInterestBips,
      delinquencyFeeBips: manifest.market.delinquencyFeeBips,
      withdrawalBatchDuration: manifest.market.withdrawalBatchDuration,
      reserveRatioBips: manifest.market.reserveRatioBips,
      delinquencyGracePeriod: manifest.market.delinquencyGracePeriod,
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

  function activationTerms(
    BRCSeriesManifest memory manifest,
    bytes32 manifestHash,
    address expectedMarket
  ) internal pure returns (ActivationTerms memory terms) {
    terms.seriesManifestHash = manifestHash;
    terms.market = expectedMarket;
    terms.borrower = manifest.market.borrower;
    terms.borrowerPrincipal = manifest.market.borrowerPrincipal;
    terms.hooksFactory = manifest.market.hooksFactory;
    terms.hooksTemplate = manifest.hooks.template;
    terms.providerFactory = manifest.hooks.providerFactory;
    terms.providerFactoryCodeHash = manifest.hooks.providerFactoryCodeHash;
    terms.marketSalt = manifest.market.marketSalt;
    terms.providerSalt = manifest.hooks.providerSalt;
    terms.annualInterestBips = manifest.market.annualInterestBips;
    terms.reserveRatioBips = manifest.market.reserveRatioBips;
    terms.delinquencyFeeBips = manifest.market.delinquencyFeeBips;
    terms.delinquencyGracePeriod = manifest.market.delinquencyGracePeriod;
    terms.withdrawalBatchDuration = manifest.market.withdrawalBatchDuration;
    terms.feeRecipient = manifest.market.feeRecipient;
    terms.protocolFeeBips = manifest.market.protocolFeeBips;
    terms.activationDeadline = manifest.vault.activationDeadline;
    terms.maturity = manifest.oracle.maturity;
    terms.btcUsdFeed = manifest.oracle.btcUsdFeed;
    terms.feedDecimals = manifest.oracle.feedDecimals;
    terms.feedDescriptionHash = manifest.oracle.feedDescriptionHash;
    terms.maxInitialAge = manifest.oracle.maxInitialAge;
    terms.maxFutureSkew = manifest.oracle.maxFutureSkew;
    terms.barrierBips = manifest.oracle.barrierBips;
    terms.maxObservationDelay = manifest.oracle.maxObservationDelay;
    terms.recoveryDelay = manifest.market.recoveryDelay;
    terms.writeOffDelay = manifest.market.writeOffDelay;
    terms.fallbackConfig.ratifiers = manifest.oracle.fallbackRatifiers;
    terms.fallbackConfig.threshold = manifest.oracle.fallbackThreshold;
    terms.fallbackConfig.waitingPeriod = manifest.oracle.fallbackWaitingPeriod;
    terms.fallbackConfig.challengePeriod = manifest.oracle.fallbackChallengePeriod;
    terms.fallbackConfig.sourceId = manifest.oracle.fallbackSourceId;
  }

  function deployVault(
    BRCSeriesManifest memory manifest,
    bytes32 manifestHash,
    address expectedMarket
  ) internal returns (BRCNoteVault vault) {
    bytes memory initCode = vaultInitCode(manifest, manifestHash, expectedMarket);
    vault = BRCNoteVault(
      IBRCVaultFactory(manifest.vault.factory).deploy(manifest.vault.salt, initCode)
    );
  }

  function atomicDeploymentInputs(
    BRCSeriesManifest memory manifest,
    bytes32 manifestHash,
    address expectedVault,
    address expectedMarket,
    address expectedHooks
  ) internal view returns (BRCAtomicDeployment memory input) {
    input.vaultFactory = manifest.vault.factory;
    input.vaultSalt = manifest.vault.salt;
    input.vaultInitCode = vaultInitCode(manifest, manifestHash, expectedMarket);
    input.hooksFactory = manifest.market.hooksFactory;
    input.hooksTemplate = manifest.hooks.template;
    input.hooksConstructorArgs = hooksConstructorArgs(manifest, expectedVault);
    input.marketInputs = marketInputs(manifest);
    input.hooksData = hooksData(manifest);
    input.marketSalt = manifest.market.marketSalt;
    input.originationFeeAsset = manifest.market.originationFeeAsset;
    input.originationFeeAmount = manifest.market.originationFeeAmount;
    input.expectedFeeRecipient = manifest.market.feeRecipient;
    input.expectedProtocolFeeBips = manifest.market.protocolFeeBips;
    input.expectedArchController = manifest.governance.archController;
    input.expectedArchControllerOwner = manifest.governance.archControllerOwner;
    input.expectedSphereXAdmin = manifest.governance.sphereXAdmin;
    input.expectedPendingSphereXAdmin = manifest.governance.pendingSphereXAdmin;
    input.expectedSphereXOperator = manifest.governance.sphereXOperator;
    input.expectedSphereXEngine = manifest.governance.sphereXEngine;
    input.expectedPrincipal = manifest.market.borrowerPrincipal;
    input.expectedHooksNonce = manifest.hooks.deploymentNonce;
    input.expectedVault = expectedVault;
    input.expectedMarket = expectedMarket;
    input.expectedHooks = expectedHooks;
  }

  function _require(bool condition, string memory field) private pure {
    if (!condition) revert InvalidManifest(field);
  }
}

contract BRCDeploymentVerifier {
  error DeploymentMismatch(string field);

  function verify(BRCSeriesManifest memory manifest, BRCDeploymentRecord memory record)
    public
    view
    returns (bool)
  {
    BRCDeploymentLib.validateManifest(manifest);
    bytes memory encodedManifest = abi.encode(manifest);
    bytes32 manifestHash = keccak256(encodedManifest);
    _check(
      keccak256(record.encodedManifest) == keccak256(encodedManifest), "record.encodedManifest"
    );
    _check(record.manifestHash == manifestHash, "record.manifestHash");
    _check(record.vault != address(0), "record.vault");
    _check(
      BRCDeploymentLib.vaultAddress(
        manifest, manifestHash, BRCDeploymentLib.marketAddress(manifest)
      ) == record.vault,
      "record.vault"
    );
    _check(BRCDeploymentLib.marketAddress(manifest) == record.market, "record.market");
    _check(BRCDeploymentLib.hooksAddress(manifest, record.vault) == record.hooks, "record.hooks");
    _check(
      BRCDeploymentLib.providerAddress(manifest, record.hooks, record.vault) == record.provider,
      "record.provider"
    );
    _check(BRCDeploymentLib.createdAddress(record.vault, 1) == record.oracle, "record.oracle");
    _check(record.vault.codehash == record.vaultCodeHash, "record.vaultCodeHash");
    _check(record.market.codehash == record.marketCodeHash, "record.marketCodeHash");
    _check(record.hooks.codehash == record.hooksCodeHash, "record.hooksCodeHash");
    _check(record.provider.codehash == record.providerCodeHash, "record.providerCodeHash");
    _check(record.oracle.codehash == record.oracleCodeHash, "record.oracleCodeHash");

    _verifyVault(manifest, record, manifestHash);
    _verifyMarket(manifest, record);
    _verifyHooks(manifest, record);
    _verifyOracle(manifest, record);
    _verifyGovernance(manifest, record);
    return true;
  }

  function _verifyVault(
    BRCSeriesManifest memory manifest,
    BRCDeploymentRecord memory record,
    bytes32 manifestHash
  ) private view {
    BRCNoteVault vault = BRCNoteVault(record.vault);
    _check(vault.seriesManifestHash() == manifestHash, "vault.seriesManifestHash");
    _check(address(vault.settlementAsset()) == manifest.market.settlementAsset, "vault.asset");
    _check(vault.accessController() == manifest.vault.accessController, "vault.accessController");
    _check(keccak256(bytes(vault.name())) == keccak256(bytes(manifest.vault.name)), "vault.name");
    _check(
      keccak256(bytes(vault.symbol())) == keccak256(bytes(manifest.vault.symbol)), "vault.symbol"
    );
    _check(vault.notional() == manifest.vault.notional, "vault.notional");
    _check(vault.minimumRaise() == manifest.vault.minimumRaise, "vault.minimumRaise");
    _check(vault.fundingDeadline() == manifest.vault.fundingDeadline, "vault.fundingDeadline");
    _check(
      vault.transfersRestricted() == manifest.vault.transfersRestricted, "vault.transfersRestricted"
    );
    _check(vault.expectedMarket() == record.market, "vault.expectedMarket");
    _check(vault.expectedBorrower() == manifest.market.borrower, "vault.expectedBorrower");
    _check(
      vault.expectedBorrowerPrincipal() == manifest.market.borrowerPrincipal,
      "vault.expectedBorrowerPrincipal"
    );
    _check(
      vault.expectedHooksFactory() == manifest.market.hooksFactory, "vault.expectedHooksFactory"
    );
    _check(vault.expectedHooksTemplate() == manifest.hooks.template, "vault.expectedHooksTemplate");
    _check(
      vault.expectedProviderFactory() == manifest.hooks.providerFactory,
      "vault.expectedProviderFactory"
    );
    _check(
      vault.expectedProviderFactoryCodeHash() == manifest.hooks.providerFactoryCodeHash,
      "vault.expectedProviderFactoryCodeHash"
    );
    _check(vault.expectedMarketSalt() == manifest.market.marketSalt, "vault.expectedMarketSalt");
    _check(
      vault.expectedProviderSalt() == manifest.hooks.providerSalt, "vault.expectedProviderSalt"
    );
    _check(
      vault.expectedAnnualInterestBips() == manifest.market.annualInterestBips,
      "vault.expectedAnnualInterestBips"
    );
    _check(
      vault.expectedReserveRatioBips() == manifest.market.reserveRatioBips,
      "vault.expectedReserveRatioBips"
    );
    _check(
      vault.expectedDelinquencyFeeBips() == manifest.market.delinquencyFeeBips,
      "vault.expectedDelinquencyFeeBips"
    );
    _check(
      vault.expectedDelinquencyGracePeriod() == manifest.market.delinquencyGracePeriod,
      "vault.expectedDelinquencyGracePeriod"
    );
    _check(
      vault.expectedWithdrawalBatchDuration() == manifest.market.withdrawalBatchDuration,
      "vault.expectedWithdrawalBatchDuration"
    );
    _check(
      vault.expectedFeeRecipient() == manifest.market.feeRecipient, "vault.expectedFeeRecipient"
    );
    _check(
      vault.expectedProtocolFeeBips() == manifest.market.protocolFeeBips,
      "vault.expectedProtocolFeeBips"
    );
    _check(
      vault.activationDeadline() == manifest.vault.activationDeadline, "vault.activationDeadline"
    );
    _check(vault.maturity() == manifest.oracle.maturity, "vault.maturity");
    _check(address(vault.fixingOracle()) == record.oracle, "vault.fixingOracle");
  }

  function _verifyMarket(BRCSeriesManifest memory manifest, BRCDeploymentRecord memory record)
    private
    view
  {
    IWildcatActivationMarket market = IWildcatActivationMarket(record.market);
    _check(
      manifest.market.borrower.codehash == manifest.market.borrowerCodeHash,
      "market.borrowerCodeHash"
    );
    _check(
      manifest.market.borrowerIdentityRegistry.codehash
        == manifest.market.borrowerIdentityRegistryCodeHash,
      "market.borrowerIdentityRegistryCodeHash"
    );
    _check(
      address(IBRCBorrowerAccountView(manifest.market.borrower).registry())
        == manifest.market.borrowerIdentityRegistry,
      "market.borrowerRegistry"
    );
    _check(
      IBorrowerIdentityRegistry(manifest.market.borrowerIdentityRegistry)
        .resolveBorrower(manifest.market.borrower) == manifest.market.borrowerPrincipal,
      "market.borrowerPrincipal"
    );
    _check(market.factory() == manifest.market.hooksFactory, "market.factory");
    _check(market.asset() == manifest.market.settlementAsset, "market.asset");
    _check(market.borrower() == manifest.market.borrower, "market.borrower");
    _check(
      market.borrowerPrincipal() == manifest.market.borrowerPrincipal, "market.borrowerPrincipal"
    );
    _check(market.pendingBorrower() == address(0), "market.pendingBorrower");
    _check(market.maxTotalSupply() == manifest.market.marketCap, "market.maxTotalSupply");
    _check(
      market.annualInterestBips() == manifest.market.annualInterestBips, "market.annualInterestBips"
    );
    _check(market.reserveRatioBips() == manifest.market.reserveRatioBips, "market.reserveRatioBips");
    _check(
      market.delinquencyFeeBips() == manifest.market.delinquencyFeeBips, "market.delinquencyFeeBips"
    );
    _check(
      market.delinquencyGracePeriod() == manifest.market.delinquencyGracePeriod,
      "market.delinquencyGracePeriod"
    );
    _check(
      market.withdrawalBatchDuration() == manifest.market.withdrawalBatchDuration,
      "market.withdrawalBatchDuration"
    );
    _check(market.feeRecipient() == manifest.market.feeRecipient, "market.feeRecipient");
    MarketState memory marketState = market.previousState();
    _check(marketState.protocolFeeBips == manifest.market.protocolFeeBips, "market.protocolFeeBips");

    HooksConfig marketHooks = market.hooks();
    _check(marketHooks.hooksAddress() == record.hooks, "market.hooks");
    _check(marketHooks.useOnDeposit(), "market.hooks.deposit");
    _check(marketHooks.useOnTransfer(), "market.hooks.transfer");
    _check(marketHooks.useOnQueueWithdrawal(), "market.hooks.queueWithdrawal");
    _check(marketHooks.useOnCloseMarket(), "market.hooks.closeMarket");
    _check(
      marketHooks.useOnSetAnnualInterestAndReserveRatioBips(),
      "market.hooks.setAnnualInterestAndReserveRatioBips"
    );
  }

  function _verifyHooks(BRCSeriesManifest memory manifest, BRCDeploymentRecord memory record)
    private
    view
  {
    FixedTermHooks hooks = FixedTermHooks(record.hooks);
    _check(
      IHooksFactoryView(manifest.market.hooksFactory).getHooksTemplateForInstance(record.hooks)
        == manifest.hooks.template,
      "hooks.template"
    );
    _check(
      keccak256(bytes(hooks.version())) == keccak256("SingletonFixedTermHooks"), "hooks.version"
    );
    _check(hooks.administrator() == manifest.market.borrowerPrincipal, "hooks.administrator");
    _check(hooks.roleProviderConfigurationSealed(), "hooks.providerConfigurationSealed");

    RoleProvider[] memory pullProviders = hooks.getPullProviders();
    RoleProvider[] memory pushProviders = hooks.getPushProviders();
    _check(pullProviders.length == 1, "hooks.pullProviderCount");
    _check(pushProviders.length == 0, "hooks.pushProviderCount");
    _check(pullProviders[0].providerAddress() == record.provider, "hooks.provider");
    _check(pullProviders[0].timeToLive() == 0, "hooks.providerTTL");
    _check(
      RoleProvider.unwrap(hooks.getRoleProvider(record.provider))
        == RoleProvider.unwrap(pullProviders[0]),
      "hooks.providerRecord"
    );
    _check(ISingletonRoleProvider(record.provider).lender() == record.vault, "provider.lender");

    HookedMarket memory policy = hooks.getHookedMarket(record.market);
    _check(policy.isHooked, "hooks.policy.isHooked");
    _check(policy.depositRequiresAccess, "hooks.policy.depositRequiresAccess");
    _check(policy.transferRequiresAccess, "hooks.policy.transferRequiresAccess");
    _check(!policy.withdrawalRequiresAccess, "hooks.policy.withdrawalRequiresAccess");
    _check(policy.fixedTermEndTime == manifest.oracle.maturity, "hooks.policy.fixedTermEndTime");
    _check(policy.minimumDeposit == 0, "hooks.policy.minimumDeposit");
    _check(policy.transfersDisabled, "hooks.policy.transfersDisabled");
    _check(!policy.allowClosureBeforeTerm, "hooks.policy.allowClosureBeforeTerm");
    _check(!policy.allowTermReduction, "hooks.policy.allowTermReduction");
  }

  function _verifyOracle(BRCSeriesManifest memory manifest, BRCDeploymentRecord memory record)
    private
    view
  {
    BtcUsdFixingOracle oracle = BtcUsdFixingOracle(record.oracle);
    _check(address(oracle.feed()) == manifest.oracle.btcUsdFeed, "oracle.feed");
    _check(oracle.recorder() == record.vault, "oracle.recorder");
    _check(oracle.expectedDecimals() == manifest.oracle.feedDecimals, "oracle.expectedDecimals");
    _check(
      oracle.expectedDescriptionHash() == manifest.oracle.feedDescriptionHash,
      "oracle.expectedDescriptionHash"
    );
    _check(oracle.maxInitialAge() == manifest.oracle.maxInitialAge, "oracle.maxInitialAge");
    _check(oracle.maxFutureSkew() == manifest.oracle.maxFutureSkew, "oracle.maxFutureSkew");
    _check(oracle.barrierBips() == manifest.oracle.barrierBips, "oracle.barrierBips");
    _check(oracle.maturity() == manifest.oracle.maturity, "oracle.maturity");
    _check(
      oracle.maxObservationDelay() == manifest.oracle.maxObservationDelay,
      "oracle.maxObservationDelay"
    );
    _check(
      oracle.fallbackAvailableAt()
        == manifest.oracle.maturity + manifest.oracle.maxObservationDelay
          + manifest.oracle.fallbackWaitingPeriod,
      "oracle.fallbackAvailableAt"
    );
    _check(
      oracle.fallbackChallengePeriod() == manifest.oracle.fallbackChallengePeriod,
      "oracle.fallbackChallengePeriod"
    );
    _check(
      oracle.fallbackThreshold() == manifest.oracle.fallbackThreshold, "oracle.fallbackThreshold"
    );
    _check(oracle.fallbackSourceId() == manifest.oracle.fallbackSourceId, "oracle.fallbackSourceId");
    _check(
      oracle.fallbackRatifierCount() == manifest.oracle.fallbackRatifiers.length,
      "oracle.fallbackRatifierCount"
    );
    for (uint256 i; i < manifest.oracle.fallbackRatifiers.length; i++) {
      _check(
        oracle.fallbackRatifiers(i) == manifest.oracle.fallbackRatifiers[i],
        "oracle.fallbackRatifier"
      );
    }
    _check(oracle.hasInitialFixing(), "oracle.initialFixing");
    (, uint128 initialPrice,) = oracle.initialFixing();
    _check(oracle.strike() == initialPrice, "oracle.strikeConvention");
  }

  function _verifyGovernance(BRCSeriesManifest memory manifest, BRCDeploymentRecord memory record)
    private
    view
  {
    IWildcatArchController archController =
      IWildcatArchController(manifest.governance.archController);
    _check(
      IHooksDeploymentFactory(manifest.market.hooksFactory).archController()
        == manifest.governance.archController,
      "governance.archController"
    );
    _check(
      archController.owner() == manifest.governance.archControllerOwner,
      "governance.archControllerOwner"
    );
    _check(
      archController.sphereXAdmin() == manifest.governance.sphereXAdmin, "governance.sphereXAdmin"
    );
    _check(
      archController.pendingSphereXAdmin() == manifest.governance.pendingSphereXAdmin,
      "governance.pendingSphereXAdmin"
    );
    _check(
      archController.sphereXOperator() == manifest.governance.sphereXOperator,
      "governance.sphereXOperator"
    );
    _check(
      archController.sphereXEngine() == manifest.governance.sphereXEngine,
      "governance.sphereXEngine"
    );
    _check(manifest.governance.sphereXEngineMutable, "governance.sphereXEngineMutable");
    _check(
      ISphereXProtectedRegisteredBase(manifest.market.hooksFactory).sphereXEngine()
        == manifest.governance.sphereXEngine,
      "governance.hooksFactorySphereXEngine"
    );
    _check(
      ISphereXProtectedRegisteredBase(record.market).sphereXEngine()
        == manifest.governance.sphereXEngine,
      "governance.marketSphereXEngine"
    );
  }

  function _check(bool condition, string memory field) private pure {
    if (!condition) revert DeploymentMismatch(field);
  }
}
