// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { BRCState } from "./BRCSeries.sol";
import { IERC20, IERC20Metadata } from "./interfaces/IERC20.sol";

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

  string public name;
  string public symbol;
  uint8 public immutable decimals;

  IERC20 public immutable settlementAsset;
  address public immutable accessController;
  uint128 public immutable notional;
  uint128 public immutable minimumRaise;
  uint40 public immutable fundingDeadline;
  bool public immutable transfersRestricted;

  BRCState public state;
  uint256 public totalSupply;
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
    bool transfersRestricted_
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
  }

  function setEligible(address account, bool eligible) external {
    if (msg.sender != accessController) revert NotAccessController();
    if (account == address(0)) revert ZeroAddress();
    isEligible[account] = eligible;
    emit EligibilitySet(account, eligible);
  }

  function approve(address spender, uint256 amount) external returns (bool) {
    if (spender == address(0)) revert ZeroAddress();
    if (transfersRestricted) {
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
}
