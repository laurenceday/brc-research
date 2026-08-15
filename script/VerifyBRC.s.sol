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

contract VerifyBRC is BRCJson, BRCDeploymentVerifier {
  function run(string memory manifestPath, string memory recordPath) external view returns (bool) {
    string memory manifestJson = vm.readFile(manifestPath);
    string memory recordJson = vm.readFile(recordPath);
    BRCSeriesManifest memory manifest = _loadManifest(manifestJson, "");
    BRCSeriesManifest memory recordedManifest = _loadManifest(recordJson, ".manifest");
    BRCDeploymentRecord memory record = _loadRecord(recordJson);
    if (BRCDeploymentLib.hashManifest(manifest) != BRCDeploymentLib.hashManifest(recordedManifest))
    {
      revert DeploymentMismatch("record.manifest");
    }
    verify(manifest, record);
    console2.log("BRC deployment matches manifest");
    return true;
  }
}
