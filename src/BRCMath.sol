// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { BRCSeriesTerms } from "./BRCSeries.sol";

library BRCMath {
  uint256 internal constant BIPS = 10_000;
  uint8 internal constant MAX_SETTLEMENT_ASSET_DECIMALS = 18;

  error ZeroNotional();
  error ZeroStrike();
  error ZeroMaturity();
  error BarrierAboveStrike();
  error InvalidBarrierBips();
  error UnsupportedSettlementAssetDecimals();
  error RebateAboveCollectedAssets();
  error InvalidNoteSupply();
  error NoteAmountAboveSupply();

  function validate(BRCSeriesTerms memory terms) internal pure {
    if (terms.notional == 0) revert ZeroNotional();
    if (terms.strike == 0) revert ZeroStrike();
    if (terms.maturity == 0) revert ZeroMaturity();
    if (terms.barrier > terms.strike) revert BarrierAboveStrike();
    if (terms.settlementAssetDecimals > MAX_SETTLEMENT_ASSET_DECIMALS) {
      revert UnsupportedSettlementAssetDecimals();
    }
  }

  /// @notice Returns floor(initialPrice * barrierBips / 10_000).
  function barrierFromBips(uint128 initialPrice, uint16 barrierBips)
    internal
    pure
    returns (uint128)
  {
    if (initialPrice == 0) revert ZeroStrike();
    if (barrierBips > BIPS) revert InvalidBarrierBips();
    // The result cannot exceed initialPrice because barrierBips is at most 10_000.
    // forge-lint: disable-next-line(unsafe-typecast)
    return uint128((uint256(initialPrice) * barrierBips) / BIPS);
  }

  function isBreached(BRCSeriesTerms memory terms, uint128 maturityPrice)
    internal
    pure
    returns (bool)
  {
    return maturityPrice <= terms.barrier;
  }

  /// @notice Returns floor(notional * (strike - maturityPrice) / strike).
  function principalSlash(BRCSeriesTerms memory terms, uint128 maturityPrice)
    internal
    pure
    returns (uint128)
  {
    validate(terms);
    if (!isBreached(terms, maturityPrice) || maturityPrice >= terms.strike) return 0;

    uint256 loss = uint256(terms.strike) - maturityPrice;
    return uint128((uint256(terms.notional) * loss) / terms.strike);
  }

  function borrowerRebate(
    BRCSeriesTerms memory terms,
    uint128 maturityPrice,
    uint128 recoveredPrincipal
  ) internal pure returns (uint128) {
    uint128 slash = principalSlash(terms, maturityPrice);
    return slash < recoveredPrincipal ? slash : recoveredPrincipal;
  }

  function noteholderPool(uint128 collectedAssets, uint128 rebate) internal pure returns (uint128) {
    if (rebate > collectedAssets) revert RebateAboveCollectedAssets();
    return collectedAssets - rebate;
  }

  /// @notice Returns floor(pool * noteAmount / totalNotes).
  function proRata(uint128 pool, uint128 noteAmount, uint128 totalNotes)
    internal
    pure
    returns (uint128)
  {
    if (totalNotes == 0) revert InvalidNoteSupply();
    if (noteAmount > totalNotes) revert NoteAmountAboveSupply();
    return uint128((uint256(pool) * noteAmount) / totalNotes);
  }
}
