// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from "./interfaces/IERC20.sol";
import { HooksTemplate, IHooksFactory } from "v2-protocol/IHooksFactory.sol";
import { IBorrowerIdentityRegistry } from "v2-protocol/interfaces/IBorrowerIdentityRegistry.sol";
import {
  ISphereXProtectedRegisteredBase
} from "v2-protocol/interfaces/ISphereXProtectedRegisteredBase.sol";
import { IWildcatArchController } from "v2-protocol/interfaces/IWildcatArchController.sol";
import { DeployMarketInputs } from "v2-protocol/interfaces/WildcatStructsAndEnums.sol";

interface IBRCAtomicVaultFactory {
  function deploy(bytes32 salt, bytes calldata initCode) external returns (address vault);

  function computeAddress(bytes32 salt, bytes32 initCodeHash) external view returns (address vault);
}

interface IBRCHooksNonce {
  function getHooksInstanceDeploymentNonce(address administrator) external view returns (uint256);
}

struct BRCAtomicDeployment {
  address vaultFactory;
  bytes32 vaultSalt;
  bytes vaultInitCode;
  address hooksFactory;
  address hooksTemplate;
  bytes hooksConstructorArgs;
  DeployMarketInputs marketInputs;
  bytes hooksData;
  bytes32 marketSalt;
  address originationFeeAsset;
  uint80 originationFeeAmount;
  address expectedFeeRecipient;
  uint16 expectedProtocolFeeBips;
  address expectedArchController;
  address expectedArchControllerOwner;
  address expectedSphereXAdmin;
  address expectedPendingSphereXAdmin;
  address expectedSphereXOperator;
  address expectedSphereXEngine;
  address expectedPrincipal;
  uint256 expectedHooksNonce;
  address expectedVault;
  address expectedMarket;
  address expectedHooks;
}

/// @notice Minimal registered borrower account used to make a BRC deployment atomic.
contract BRCBorrowerAccount {
  error CallerNotPrincipal();
  error DeploymentMismatch(string field);
  error ReentrantCall();
  error ApprovalFailed();

  IBorrowerIdentityRegistry public immutable registry;
  bool private locked;

  constructor(address registry_) {
    if (registry_ == address(0) || registry_.code.length == 0) {
      revert DeploymentMismatch("registry");
    }
    registry = IBorrowerIdentityRegistry(registry_);
  }

  receive() external payable { }

  modifier onlyPrincipal() {
    if (msg.sender != principal()) revert CallerNotPrincipal();
    _;
  }

  modifier nonReentrant() {
    if (locked) revert ReentrantCall();
    locked = true;
    _;
    locked = false;
  }

  function principal() public view returns (address) {
    return registry.principalOf(address(this));
  }

  function deploySeries(BRCAtomicDeployment calldata input)
    external
    onlyPrincipal
    nonReentrant
    returns (address vault, address market, address hooks)
  {
    _check(input.expectedPrincipal == principal(), "principal");
    _check(address(bytes20(input.vaultSalt)) == address(this), "vaultSalt");
    _check(address(bytes20(input.marketSalt)) == address(this), "marketSalt");
    _check(
      IBRCHooksNonce(input.hooksFactory).getHooksInstanceDeploymentNonce(input.expectedPrincipal)
        == input.expectedHooksNonce,
      "hooksNonce"
    );
    _checkGovernance(input);
    _check(
      IBRCAtomicVaultFactory(input.vaultFactory)
        .computeAddress(input.vaultSalt, keccak256(input.vaultInitCode)) == input.expectedVault,
      "vault"
    );

    vault = IBRCAtomicVaultFactory(input.vaultFactory).deploy(input.vaultSalt, input.vaultInitCode);
    _check(vault == input.expectedVault, "vault");

    if (input.originationFeeAmount != 0) {
      IERC20 feeAsset = IERC20(input.originationFeeAsset);
      _check(feeAsset.allowance(address(this), input.hooksFactory) == 0, "feeAllowance");
      if (!feeAsset.approve(input.hooksFactory, input.originationFeeAmount)) {
        revert ApprovalFailed();
      }
    }

    _check(input.expectedPrincipal == principal(), "principal");
    _check(
      IBRCHooksNonce(input.hooksFactory).getHooksInstanceDeploymentNonce(input.expectedPrincipal)
        == input.expectedHooksNonce,
      "hooksNonce"
    );
    _checkGovernance(input);
    (market, hooks) = IHooksFactory(input.hooksFactory)
      .deployMarketAndHooks(
        input.hooksTemplate,
        input.hooksConstructorArgs,
        input.marketInputs,
        input.hooksData,
        input.marketSalt,
        input.originationFeeAsset,
        input.originationFeeAmount
      );

    if (input.originationFeeAmount != 0) {
      if (!IERC20(input.originationFeeAsset).approve(input.hooksFactory, 0)) {
        revert ApprovalFailed();
      }
    }
    _check(market == input.expectedMarket, "market");
    _check(hooks == input.expectedHooks, "hooks");
  }

  function execute(address target, uint256 value, bytes calldata data)
    external
    payable
    onlyPrincipal
    nonReentrant
    returns (bytes memory result)
  {
    bool success;
    (success, result) = target.call{ value: value }(data);
    if (!success) {
      assembly ("memory-safe") {
        revert(add(result, 0x20), mload(result))
      }
    }
  }

  function _check(bool condition, string memory field) private pure {
    if (!condition) revert DeploymentMismatch(field);
  }

  function _checkGovernance(BRCAtomicDeployment calldata input) private view {
    IHooksFactory hooksFactory = IHooksFactory(input.hooksFactory);
    _check(hooksFactory.archController() == input.expectedArchController, "archController");
    HooksTemplate memory template = hooksFactory.getHooksTemplateDetails(input.hooksTemplate);
    _check(template.exists && template.enabled, "hooksTemplate");
    _check(template.feeRecipient == input.expectedFeeRecipient, "feeRecipient");
    _check(template.protocolFeeBips == input.expectedProtocolFeeBips, "protocolFeeBips");
    _check(template.originationFeeAsset == input.originationFeeAsset, "originationFeeAsset");
    _check(template.originationFeeAmount == input.originationFeeAmount, "originationFeeAmount");

    IWildcatArchController archController = IWildcatArchController(input.expectedArchController);
    _check(archController.owner() == input.expectedArchControllerOwner, "archControllerOwner");
    _check(archController.sphereXAdmin() == input.expectedSphereXAdmin, "sphereXAdmin");
    _check(
      archController.pendingSphereXAdmin() == input.expectedPendingSphereXAdmin,
      "pendingSphereXAdmin"
    );
    _check(archController.sphereXOperator() == input.expectedSphereXOperator, "sphereXOperator");
    _check(archController.sphereXEngine() == input.expectedSphereXEngine, "sphereXEngine");
    _check(
      ISphereXProtectedRegisteredBase(input.hooksFactory).sphereXEngine()
        == input.expectedSphereXEngine,
      "hooksFactorySphereXEngine"
    );
  }
}

/// @notice Factory that creates and registers a BRC borrower account.
contract BRCBorrowerAccountFactory {
  IBorrowerIdentityRegistry public immutable registry;

  constructor(address registry_) {
    if (registry_ == address(0) || registry_.code.length == 0) {
      revert BRCBorrowerAccount.DeploymentMismatch("registry");
    }
    registry = IBorrowerIdentityRegistry(registry_);
  }

  function deployAccount(address principal) external returns (BRCBorrowerAccount account) {
    account = new BRCBorrowerAccount(address(registry));
    registry.registerBorrowerAccount(address(account), principal);
  }
}
