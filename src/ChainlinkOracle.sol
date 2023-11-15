// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import {IOracle} from "../lib/morpho-blue/src/interfaces/IOracle.sol";

import {AggregatorV3Interface, ChainlinkDataFeedLib} from "./libraries/ChainlinkDataFeedLib.sol";
import {IERC4626, VaultLib} from "./libraries/VaultLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {Source,SourceLib} from "./libraries/SourceLib.sol";

/// @title ChainlinkOracle
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Morpho Blue oracle using Chainlink-compliant feeds and 4626 vaults.
contract ChainlinkOracle is IOracle {
    using SourceLib for Source;

    /* IMMUTABLES */

    /// @notice Price scale factor, computed at contract creation.
    uint256 public immutable SCALE_FACTOR;

    /* CONSTRUCTOR */
    /// @notice First base source address.
    address public immutable BASE_SOURCE_1_ADDRESS;
    /// @notice Second base source address.
    address public immutable BASE_SOURCE_2_ADDRESS;
    /// @notice First quote source address.
    address public immutable QUOTE_SOURCE_1_ADDRESS;
    /// @notice Second quote source address.
    address public immutable QUOTE_SOURCE_2_ADDRESS;

    /// @notice First base source getter.
    function(address,uint) view internal returns (uint) internal immutable BASE_SOURCE_1_GET;
    /// @notice Second base source getter.
    function(address,uint) view internal returns (uint) internal immutable BASE_SOURCE_2_GET;
    /// @notice First quote source getter.
    function(address,uint) view internal returns (uint) internal immutable QUOTE_SOURCE_1_GET;
    /// @notice Second quote source getter.
    function(address,uint) view internal returns (uint) internal immutable QUOTE_SOURCE_2_GET;

    // The vault parameters are used for ERC4626 tokens, to price their shares.
    /// @notice First base vault conversion sample (0 if first base source is not a vault).
    uint256 public immutable BASE_VAULT_1_CONVERSION_SAMPLE;
    /// @notice Second base vault conversion sample (0 if second base source is not a vault).
    uint256 public immutable BASE_VAULT_2_CONVERSION_SAMPLE;
    /// @notice First quote vault conversion sample (0 if first quote source is not a vault).
    uint256 public immutable QUOTE_VAULT_1_CONVERSION_SAMPLE;
    /// @notice Second quote vault conversion sample (0 if second quote source is not a vault).
    uint256 public immutable QUOTE_VAULT_2_CONVERSION_SAMPLE;

    /// @param baseSource1 First base source. Pass Source(0,_) if the price = 1. Pass Source(feed,0) if source is a feed.
    /// @param baseSource2 Second base feed. Pass Source(0,_) if the price = 1. Pass Source(feed,0) if source is a feed.
    /// @param quoteSource1 First quote feed. Pass Source(0,_) if the price = 1. Pass Source(feed,0) if source is a feed.
    /// @param quoteSource2 Second quote feed. Pass Source(0,_) if the price = 1. Pass Source(feed,0) if source is a feed.
    /// @param baseTokenDecimals Base token decimals.
    /// @param quoteTokenDecimals Quote token decimals.
    constructor(
        Source memory baseSource1,
        Source memory baseSource2,
        Source memory quoteSource1,
        Source memory quoteSource2,
        uint256 baseTokenDecimals,
        uint256 quoteTokenDecimals
    ) {
        (BASE_SOURCE_1_ADDRESS, BASE_SOURCE_1_GET, BASE_VAULT_1_CONVERSION_SAMPLE) = baseSource1.getParams();

        (BASE_SOURCE_2_ADDRESS, BASE_SOURCE_2_GET, BASE_VAULT_2_CONVERSION_SAMPLE) = baseSource2.getParams();

        (QUOTE_SOURCE_1_ADDRESS, QUOTE_SOURCE_1_GET, QUOTE_VAULT_1_CONVERSION_SAMPLE) = quoteSource1.getParams();

        (QUOTE_SOURCE_2_ADDRESS, QUOTE_SOURCE_2_GET, QUOTE_VAULT_2_CONVERSION_SAMPLE) = quoteSource2.getParams();

        // Let pB1 and pB2 be the base prices, and pQ1 and pQ2 the quote prices (price taking into account the
        // decimals of both tokens), in a common currency.
        // We tackle the most general case in the remainder of this comment, where we assume that no feed is the address
        // zero. Similar explanations would hold in the case where some of the feeds are the address zero.
        // Let dB1, dB2, dB3, and dQ1, dQ2, dQ3 be the decimals of the tokens involved.
        // For example, pB1 is the number of 1e(dB2) of the second base asset that can be obtained from 1e(dB1) of
        // the first base asset.
        // We notably have dB3 = dQ3, because those two quantities are the decimals of the same common currency.
        // Let fpB1, fpB2, fpQ1 and fpQ2 be the feed precision of the corresponding prices.
        // Chainlink feeds return pB1*1e(fpB1), pB2*1e(fpB2), pQ1*1e(fpQ1) and pQ2*1e(fpQ2).
        // Because the Blue oracle does not take into account decimals, `price()` should return
        // 1e36 * (pB1*1e(dB2-dB1) * pB2*1e(dB3-dB2)) / (pQ1*1e(dQ2-dQ1) * pQ2*1e(dQ3-dQ2))
        // Yet `price()` returns (pB1*1e(fpB1) * pB2*1e(fpB2) * SCALE_FACTOR) / (pQ1*1e(fpQ1) * pQ2*1e(fpQ2))
        // So 1e36 * pB1 * pB2 * 1e(-dB1) / (pQ1 * pQ2 * 1e(-dQ1)) =
        // (pB1*1e(fpB1) * pB2*1e(fpB2) * SCALE_FACTOR) / (pQ1*1e(fpQ1) * pQ2*1e(fpQ2))
        // So SCALE_FACTOR = 1e36 * 1e(-dB1) * 1e(dQ1) * 1e(-fpB1) * 1e(-fpB2) * 1e(fpQ1) * 1e(fpQ2)
        //                 = 1e(36 + dQ1 + fpQ1 + fpQ2 - dB1 - fpB1 - fpB2)
        SCALE_FACTOR = 10 ** (
            36 + quoteTokenDecimals + quoteSource1.getDecimals() + quoteSource2.getDecimals() - baseTokenDecimals
                - baseSource1.getDecimals() - baseSource2.getDecimals());
    }

    function price() external view returns (uint256) {
        return SCALE_FACTOR * BASE_SOURCE_1_GET(BASE_SOURCE_1_ADDRESS, BASE_VAULT_1_CONVERSION_SAMPLE)
            * BASE_SOURCE_2_GET(BASE_SOURCE_2_ADDRESS, BASE_VAULT_2_CONVERSION_SAMPLE)
            / (
                QUOTE_SOURCE_1_GET(QUOTE_SOURCE_1_ADDRESS, QUOTE_VAULT_1_CONVERSION_SAMPLE)
                    * QUOTE_SOURCE_2_GET(QUOTE_SOURCE_2_ADDRESS, QUOTE_VAULT_2_CONVERSION_SAMPLE)
            );
    }
}
