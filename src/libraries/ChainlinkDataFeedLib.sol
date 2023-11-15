// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "../interfaces/AggregatorV3Interface.sol";

import {ErrorsLib} from "./ErrorsLib.sol";

/// @title ChainlinkDataFeedLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing functions to interact with a Chainlink-compliant feed.
library ChainlinkDataFeedLib {
    /// @dev Performs safety checks and returns the latest price of a `feed`.
    /// @dev When `feed` is the address zero, returns 1.
    /// @dev Notes on safety checks:
    /// - Staleness is not checked because it's assumed that the Chainlink feed keeps its promises on this.
    /// - The price is not checked to be in the min/max bounds because it's assumed that the Chainlink feed keeps its
    /// promises on this.
    // We ignore the second argument but must have it to match the signature of VaultLib.getAssets(vault,sharesAmount)
    function getPrice(address feed, uint256) internal view returns (uint256) {
        if (feed == address(0)) return 1;

        (, int256 answer,,,) = AggregatorV3Interface(feed).latestRoundData();
        require(answer >= 0, ErrorsLib.NEGATIVE_ANSWER);

        return uint256(answer);
    }

    /// @dev Returns the number of decimals of a `feed`.
    /// @dev When `feed` is the address zero, returns 0.
    function getDecimals(address feed) internal view returns (uint256) {
        if (feed == address(0)) return 0;

        return AggregatorV3Interface(feed).decimals();
    }
}
