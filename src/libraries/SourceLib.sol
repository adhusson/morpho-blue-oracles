// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {VaultLib} from "./VaultLib.sol";
import {ChainlinkDataFeedLib} from "./ChainlinkDataFeedLib.sol";

// Is a feed if sampleDecimals == 0
// Is a vault otherwise
struct Source {
    address addr;
    uint256 sampleDecimals;
}
/// @title SourceLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing functions to interact with a valid Oracle source (Chainlink feed or 4626 vault)
library SourceLib {

    /// @dev Returns the source address, source getter, and source vault conversion sample (0 if source is a feed)
    function getParams(Source memory source)
        internal
        pure
        returns (address addr, function(address,uint) internal view returns (uint) get, uint256 sampleSize)
    {
        addr = source.addr;
        if (source.sampleDecimals == 0) {
            get = ChainlinkDataFeedLib.getPrice;
        } else {
            get = VaultLib.getAssets;
            sampleSize = 10**source.sampleDecimals;
        }
    }

    /// @dev Returns the source scaling.
    /// @dev Is feed decimals if source is a feed (indicated by sampleDecimals == 0)
    /// @dev Is source's sampleDecimals otherwise
    function getDecimals(Source memory source) internal view returns (uint256) {
        if (source.sampleDecimals == 0) {
            return ChainlinkDataFeedLib.getDecimals(source.addr);
        } else {
            return source.sampleDecimals;
        }
    }
}

