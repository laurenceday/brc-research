// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract BRCVaultFactory {
  error SaltDoesNotContainSender();
  error DeploymentFailed();

  event VaultDeployed(address indexed vault, address indexed deployer, bytes32 indexed salt);

  function deploy(bytes32 salt, bytes calldata initCode) external returns (address vault) {
    if (address(bytes20(salt)) != msg.sender) revert SaltDoesNotContainSender();
    assembly ("memory-safe") {
      let pointer := mload(0x40)
      calldatacopy(pointer, initCode.offset, initCode.length)
      vault := create2(0, pointer, initCode.length, salt)
    }
    if (vault == address(0)) revert DeploymentFailed();
    emit VaultDeployed(vault, msg.sender, salt);
  }

  function computeAddress(bytes32 salt, bytes32 initCodeHash)
    external
    view
    returns (address vault)
  {
    vault = address(
      uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, initCodeHash))))
    );
  }
}
