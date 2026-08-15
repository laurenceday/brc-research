// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script } from "forge-std/Script.sol";
import {
  BRCBuildManifest,
  BRCDeploymentRecord,
  BRCGovernanceManifest,
  BRCHooksManifest,
  BRCMarketManifest,
  BRCOracleManifest,
  BRCSeriesManifest,
  BRCVaultManifest
} from "../src/BRCDeployment.sol";

abstract contract BRCJson is Script {
  error JsonValueOutOfRange(string field);

  function _loadManifest(string memory json, string memory prefix)
    internal
    view
    returns (BRCSeriesManifest memory manifest)
  {
    manifest.build = _loadBuild(json, prefix);
    manifest.vault = _loadVault(json, prefix);
    manifest.market = _loadMarket(json, prefix);
    manifest.hooks = _loadHooks(json, prefix);
    manifest.oracle = _loadOracle(json, prefix);
    manifest.governance = _loadGovernance(json, prefix);
  }

  function _loadBuild(string memory json, string memory prefix)
    private
    view
    returns (BRCBuildManifest memory value)
  {
    value.chainId = vm.parseJsonUint(json, _key(prefix, "build.chainId"));
    value.environment = vm.parseJsonString(json, _key(prefix, "build.environment"));
    value.brcResearchCommit = vm.parseJsonString(json, _key(prefix, "build.brcResearchCommit"));
    value.v2ProtocolCommit = vm.parseJsonString(json, _key(prefix, "build.v2ProtocolCommit"));
    value.compilerVersion = vm.parseJsonString(json, _key(prefix, "build.compilerVersion"));
    value.evmVersion = vm.parseJsonString(json, _key(prefix, "build.evmVersion"));
    value.optimizer = vm.parseJsonBool(json, _key(prefix, "build.optimizer"));
    value.optimizerRuns =
      uint32(_boundedUint(json, _key(prefix, "build.optimizerRuns"), type(uint32).max));
    value.viaIR = vm.parseJsonBool(json, _key(prefix, "build.viaIR"));
    value.bytecodeHash = vm.parseJsonString(json, _key(prefix, "build.bytecodeHash"));
  }

  function _loadVault(string memory json, string memory prefix)
    private
    view
    returns (BRCVaultManifest memory value)
  {
    value.name = vm.parseJsonString(json, _key(prefix, "vault.name"));
    value.symbol = vm.parseJsonString(json, _key(prefix, "vault.symbol"));
    value.accessController = vm.parseJsonAddress(json, _key(prefix, "vault.accessController"));
    value.transfersRestricted = vm.parseJsonBool(json, _key(prefix, "vault.transfersRestricted"));
    value.notional = uint128(_boundedUint(json, _key(prefix, "vault.notional"), type(uint128).max));
    value.minimumRaise =
      uint128(_boundedUint(json, _key(prefix, "vault.minimumRaise"), type(uint128).max));
    value.fundingDeadline =
      uint40(_boundedUint(json, _key(prefix, "vault.fundingDeadline"), type(uint40).max));
    value.activationDeadline =
      uint40(_boundedUint(json, _key(prefix, "vault.activationDeadline"), type(uint40).max));
    value.factory = vm.parseJsonAddress(json, _key(prefix, "vault.factory"));
    value.factoryCodeHash = vm.parseJsonBytes32(json, _key(prefix, "vault.factoryCodeHash"));
    value.salt = vm.parseJsonBytes32(json, _key(prefix, "vault.salt"));
  }

  function _loadMarket(string memory json, string memory prefix)
    private
    view
    returns (BRCMarketManifest memory value)
  {
    value.borrower = vm.parseJsonAddress(json, _key(prefix, "market.borrower"));
    value.borrowerCodeHash = vm.parseJsonBytes32(json, _key(prefix, "market.borrowerCodeHash"));
    value.borrowerPrincipal = vm.parseJsonAddress(json, _key(prefix, "market.borrowerPrincipal"));
    value.borrowerIdentityRegistry =
      vm.parseJsonAddress(json, _key(prefix, "market.borrowerIdentityRegistry"));
    value.borrowerIdentityRegistryCodeHash =
      vm.parseJsonBytes32(json, _key(prefix, "market.borrowerIdentityRegistryCodeHash"));
    value.hooksFactory = vm.parseJsonAddress(json, _key(prefix, "market.hooksFactory"));
    value.hooksFactoryCodeHash =
      vm.parseJsonBytes32(json, _key(prefix, "market.hooksFactoryCodeHash"));
    value.marketSalt = vm.parseJsonBytes32(json, _key(prefix, "market.marketSalt"));
    value.settlementAsset = vm.parseJsonAddress(json, _key(prefix, "market.settlementAsset"));
    value.namePrefix = vm.parseJsonString(json, _key(prefix, "market.namePrefix"));
    value.symbolPrefix = vm.parseJsonString(json, _key(prefix, "market.symbolPrefix"));
    value.marketCap =
      uint128(_boundedUint(json, _key(prefix, "market.marketCap"), type(uint128).max));
    value.annualInterestBips =
      uint16(_boundedUint(json, _key(prefix, "market.annualInterestBips"), type(uint16).max));
    value.reserveRatioBips =
      uint16(_boundedUint(json, _key(prefix, "market.reserveRatioBips"), type(uint16).max));
    value.delinquencyFeeBips =
      uint16(_boundedUint(json, _key(prefix, "market.delinquencyFeeBips"), type(uint16).max));
    value.delinquencyGracePeriod =
      uint32(_boundedUint(json, _key(prefix, "market.delinquencyGracePeriod"), type(uint32).max));
    value.withdrawalBatchDuration =
      uint32(_boundedUint(json, _key(prefix, "market.withdrawalBatchDuration"), type(uint32).max));
    value.feeRecipient = vm.parseJsonAddress(json, _key(prefix, "market.feeRecipient"));
    value.protocolFeeBips =
      uint16(_boundedUint(json, _key(prefix, "market.protocolFeeBips"), type(uint16).max));
    value.originationFeeAsset =
      vm.parseJsonAddress(json, _key(prefix, "market.originationFeeAsset"));
    value.originationFeeAmount =
      uint80(_boundedUint(json, _key(prefix, "market.originationFeeAmount"), type(uint80).max));
    value.recoveryDelay =
      uint32(_boundedUint(json, _key(prefix, "market.recoveryDelay"), type(uint32).max));
    value.writeOffDelay =
      uint32(_boundedUint(json, _key(prefix, "market.writeOffDelay"), type(uint32).max));
  }

  function _loadHooks(string memory json, string memory prefix)
    private
    view
    returns (BRCHooksManifest memory value)
  {
    value.template = vm.parseJsonAddress(json, _key(prefix, "hooks.template"));
    value.templateCodeHash = vm.parseJsonBytes32(json, _key(prefix, "hooks.templateCodeHash"));
    value.providerFactory = vm.parseJsonAddress(json, _key(prefix, "hooks.providerFactory"));
    value.providerFactoryCodeHash =
      vm.parseJsonBytes32(json, _key(prefix, "hooks.providerFactoryCodeHash"));
    value.providerSalt = vm.parseJsonBytes32(json, _key(prefix, "hooks.providerSalt"));
    value.deploymentNonce = vm.parseJsonUint(json, _key(prefix, "hooks.deploymentNonce"));
    value.name = vm.parseJsonString(json, _key(prefix, "hooks.name"));
  }

  function _loadOracle(string memory json, string memory prefix)
    private
    view
    returns (BRCOracleManifest memory value)
  {
    value.btcUsdFeed = vm.parseJsonAddress(json, _key(prefix, "oracle.btcUsdFeed"));
    value.feedCodeHash = vm.parseJsonBytes32(json, _key(prefix, "oracle.feedCodeHash"));
    value.feedDecimals =
      uint8(_boundedUint(json, _key(prefix, "oracle.feedDecimals"), type(uint8).max));
    value.feedDescriptionHash =
      vm.parseJsonBytes32(json, _key(prefix, "oracle.feedDescriptionHash"));
    value.maxInitialAge =
      uint32(_boundedUint(json, _key(prefix, "oracle.maxInitialAge"), type(uint32).max));
    value.maxFutureSkew =
      uint32(_boundedUint(json, _key(prefix, "oracle.maxFutureSkew"), type(uint32).max));
    value.strikeAtInitialFixing =
      vm.parseJsonBool(json, _key(prefix, "oracle.strikeAtInitialFixing"));
    value.barrierObservedOnlyAtMaturity =
      vm.parseJsonBool(json, _key(prefix, "oracle.barrierObservedOnlyAtMaturity"));
    value.barrierBips =
      uint16(_boundedUint(json, _key(prefix, "oracle.barrierBips"), type(uint16).max));
    value.maturity = uint40(_boundedUint(json, _key(prefix, "oracle.maturity"), type(uint40).max));
    value.maxObservationDelay =
      uint32(_boundedUint(json, _key(prefix, "oracle.maxObservationDelay"), type(uint32).max));
    value.fallbackRatifiers =
      vm.parseJsonAddressArray(json, _key(prefix, "oracle.fallbackRatifiers"));
    value.fallbackThreshold =
      uint8(_boundedUint(json, _key(prefix, "oracle.fallbackThreshold"), type(uint8).max));
    value.fallbackWaitingPeriod =
      uint32(_boundedUint(json, _key(prefix, "oracle.fallbackWaitingPeriod"), type(uint32).max));
    value.fallbackChallengePeriod =
      uint32(_boundedUint(json, _key(prefix, "oracle.fallbackChallengePeriod"), type(uint32).max));
    value.fallbackSourceId = vm.parseJsonBytes32(json, _key(prefix, "oracle.fallbackSourceId"));
  }

  function _loadGovernance(string memory json, string memory prefix)
    private
    view
    returns (BRCGovernanceManifest memory value)
  {
    value.archController = vm.parseJsonAddress(json, _key(prefix, "governance.archController"));
    value.archControllerOwner =
      vm.parseJsonAddress(json, _key(prefix, "governance.archControllerOwner"));
    value.sphereXAdmin = vm.parseJsonAddress(json, _key(prefix, "governance.sphereXAdmin"));
    value.pendingSphereXAdmin =
      vm.parseJsonAddress(json, _key(prefix, "governance.pendingSphereXAdmin"));
    value.sphereXOperator = vm.parseJsonAddress(json, _key(prefix, "governance.sphereXOperator"));
    value.sphereXEngine = vm.parseJsonAddress(json, _key(prefix, "governance.sphereXEngine"));
    value.sphereXEngineMutable =
      vm.parseJsonBool(json, _key(prefix, "governance.sphereXEngineMutable"));
  }

  function _loadRecord(string memory json)
    internal
    view
    returns (BRCDeploymentRecord memory record)
  {
    record.encodedManifest = vm.parseJsonBytes(json, ".encodedManifest");
    record.manifestHash = vm.parseJsonBytes32(json, ".manifestHash");
    record.vault = vm.parseJsonAddress(json, ".deployment.vault");
    record.market = vm.parseJsonAddress(json, ".deployment.market");
    record.hooks = vm.parseJsonAddress(json, ".deployment.hooks");
    record.provider = vm.parseJsonAddress(json, ".deployment.provider");
    record.oracle = vm.parseJsonAddress(json, ".deployment.oracle");
    record.vaultCodeHash = vm.parseJsonBytes32(json, ".codeHashes.vault");
    record.marketCodeHash = vm.parseJsonBytes32(json, ".codeHashes.market");
    record.hooksCodeHash = vm.parseJsonBytes32(json, ".codeHashes.hooks");
    record.providerCodeHash = vm.parseJsonBytes32(json, ".codeHashes.provider");
    record.oracleCodeHash = vm.parseJsonBytes32(json, ".codeHashes.oracle");
  }

  function _key(string memory prefix, string memory field) private pure returns (string memory) {
    if (bytes(prefix).length == 0) return string.concat(".", field);
    return string.concat(prefix, ".", field);
  }

  function _boundedUint(string memory json, string memory field, uint256 maximum)
    private
    view
    returns (uint256 value)
  {
    value = vm.parseJsonUint(json, field);
    if (value > maximum) revert JsonValueOutOfRange(field);
  }
}
