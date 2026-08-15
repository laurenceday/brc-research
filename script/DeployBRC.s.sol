// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console2 } from "forge-std/console2.sol";
import { BRCJson } from "./BRCJson.sol";
import {
  BRCDeploymentLib,
  BRCDeploymentRecord,
  BRCDeploymentVerifier,
  BRCSeriesManifest
} from "../src/BRCDeployment.sol";
import { BRCNoteVault } from "../src/BRCNoteVault.sol";
import { BRCAtomicDeployment, BRCBorrowerAccount } from "../src/BRCBorrowerAccount.sol";

contract DeployBRC is BRCJson, BRCDeploymentVerifier {
  error AddressMismatch(string field);

  function run(string memory manifestPath, string memory recordPath)
    external
    returns (BRCDeploymentRecord memory record)
  {
    string memory manifestJson = vm.readFile(manifestPath);
    BRCSeriesManifest memory manifest = _loadManifest(manifestJson, "");
    BRCDeploymentLib.validatePredeployment(manifest);

    address expectedMarket = BRCDeploymentLib.marketAddress(manifest);
    bytes32 manifestHash = BRCDeploymentLib.hashManifest(manifest);
    address expectedVault = BRCDeploymentLib.vaultAddress(manifest, manifestHash, expectedMarket);
    address expectedHooks = BRCDeploymentLib.hooksAddress(manifest, expectedVault);
    address expectedProvider =
      BRCDeploymentLib.providerAddress(manifest, expectedHooks, expectedVault);

    _printPreflight(
      manifest, manifestHash, expectedVault, expectedMarket, expectedHooks, expectedProvider
    );

    BRCAtomicDeployment memory input = BRCDeploymentLib.atomicDeploymentInputs(
      manifest, manifestHash, expectedVault, expectedMarket, expectedHooks
    );
    vm.startBroadcast(manifest.market.borrowerPrincipal);
    (address vaultAddress, address market, address hooks) =
      BRCBorrowerAccount(payable(manifest.market.borrower)).deploySeries(input);
    vm.stopBroadcast();

    if (vaultAddress != expectedVault) revert AddressMismatch("vault");
    if (market != expectedMarket) revert AddressMismatch("market");
    if (hooks != expectedHooks) revert AddressMismatch("hooks");
    BRCNoteVault vault = BRCNoteVault(vaultAddress);
    address provider = BRCDeploymentLib.providerAddress(manifest, hooks, vaultAddress);
    if (provider != expectedProvider) revert AddressMismatch("provider");

    record = BRCDeploymentRecord({
      encodedManifest: abi.encode(manifest),
      manifestHash: manifestHash,
      vault: vaultAddress,
      market: market,
      hooks: hooks,
      provider: provider,
      oracle: address(vault.fixingOracle()),
      vaultCodeHash: vaultAddress.codehash,
      marketCodeHash: market.codehash,
      hooksCodeHash: hooks.codehash,
      providerCodeHash: provider.codehash,
      oracleCodeHash: address(vault.fixingOracle()).codehash
    });
    verify(manifest, record);
    _writeRecord(recordPath, manifestJson, record);
    console2.log("verification: ok");
  }

  function _printPreflight(
    BRCSeriesManifest memory manifest,
    bytes32 manifestHash,
    address expectedVault,
    address expectedMarket,
    address expectedHooks,
    address expectedProvider
  ) private pure {
    console2.log("BRC deployment sign-off");
    console2.log("environment", manifest.build.environment);
    console2.log("chain id", manifest.build.chainId);
    console2.log("brc-research revision", manifest.build.brcResearchCommit);
    console2.log("v2-protocol revision", manifest.build.v2ProtocolCommit);
    console2.log("compiler", manifest.build.compilerVersion);
    console2.log("manifest hash");
    console2.logBytes32(manifestHash);
    console2.log("hooks factory code hash");
    console2.logBytes32(manifest.market.hooksFactoryCodeHash);
    console2.log("borrower account code hash");
    console2.logBytes32(manifest.market.borrowerCodeHash);
    console2.log("borrower identity registry code hash");
    console2.logBytes32(manifest.market.borrowerIdentityRegistryCodeHash);
    console2.log("hooks template code hash");
    console2.logBytes32(manifest.hooks.templateCodeHash);
    console2.log("provider factory code hash");
    console2.logBytes32(manifest.hooks.providerFactoryCodeHash);
    console2.log("feed code hash");
    console2.logBytes32(manifest.oracle.feedCodeHash);
    console2.log("vault factory code hash");
    console2.logBytes32(manifest.vault.factoryCodeHash);
    console2.log("ArchController", manifest.governance.archController);
    console2.log("ArchController owner", manifest.governance.archControllerOwner);
    console2.log("SphereX admin", manifest.governance.sphereXAdmin);
    console2.log("SphereX pending admin", manifest.governance.pendingSphereXAdmin);
    console2.log("SphereX operator", manifest.governance.sphereXOperator);
    console2.log("SphereX engine", manifest.governance.sphereXEngine);
    console2.log("vault", expectedVault);
    console2.log("market", expectedMarket);
    console2.log("hooks", expectedHooks);
    console2.log("provider", expectedProvider);
  }

  function _writeRecord(
    string memory path,
    string memory manifestJson,
    BRCDeploymentRecord memory record
  ) private {
    string memory deployment = string.concat(
      "{\"vault\":\"",
      vm.toString(record.vault),
      "\",\"market\":\"",
      vm.toString(record.market),
      "\",\"hooks\":\"",
      vm.toString(record.hooks),
      "\",\"provider\":\"",
      vm.toString(record.provider),
      "\",\"oracle\":\"",
      vm.toString(record.oracle),
      "\"}"
    );
    string memory codeHashes = string.concat(
      "{\"vault\":\"",
      vm.toString(record.vaultCodeHash),
      "\",\"market\":\"",
      vm.toString(record.marketCodeHash),
      "\",\"hooks\":\"",
      vm.toString(record.hooksCodeHash),
      "\",\"provider\":\"",
      vm.toString(record.providerCodeHash),
      "\",\"oracle\":\"",
      vm.toString(record.oracleCodeHash),
      "\"}"
    );
    string memory json = string.concat(
      "{\"manifest\":",
      manifestJson,
      ",\"encodedManifest\":\"",
      vm.toString(record.encodedManifest),
      "\",\"manifestHash\":\"",
      vm.toString(record.manifestHash),
      "\",\"deployment\":",
      deployment,
      ",\"codeHashes\":",
      codeHashes,
      "}"
    );
    vm.writeJson(json, path);
  }
}
