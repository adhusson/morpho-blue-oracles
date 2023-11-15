// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../src/ChainlinkOracle.sol";
import "../src/libraries/ErrorsLib.sol";
import "./mocks/ChainlinkAggregatorMock.sol";

AggregatorV3Interface constant feedZero = AggregatorV3Interface(address(0));
// 8 decimals of precision
AggregatorV3Interface constant btcUsdFeed = AggregatorV3Interface(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c);
// 8 decimals of precision
AggregatorV3Interface constant usdcUsdFeed = AggregatorV3Interface(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
// 18 decimals of precision
AggregatorV3Interface constant btcEthFeed = AggregatorV3Interface(0xdeb288F737066589598e9214E782fa5A8eD689e8);
// 8 decimals of precision
AggregatorV3Interface constant wBtcBtcFeed = AggregatorV3Interface(0xfdFD9C85aD200c506Cf9e21F1FD8dd01932FBB23);
// 18 decimals of precision
AggregatorV3Interface constant stEthEthFeed = AggregatorV3Interface(0x86392dC19c0b719886221c78AB11eb8Cf5c52812);
// 18 decimals of precision
AggregatorV3Interface constant usdcEthFeed = AggregatorV3Interface(0x986b5E1e1755e3C2440e960477f25201B0a8bbD4);
// 8 decimals of precision
AggregatorV3Interface constant ethUsdFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
// 18 decimals of precision
AggregatorV3Interface constant daiEthFeed = AggregatorV3Interface(0x773616E4d11A78F511299002da57A0a94577F1f4);

function source(AggregatorV3Interface feed) pure returns (Source memory) {
    return Source(address(feed), 0);
}

function source(IERC4626 vault, uint256 conversionSample) pure returns (Source memory) {
    return Source(address(vault), conversionSample);
}

IERC4626 constant sDaiVault = IERC4626(0x83F20F44975D03b1b09e64809B757c47f942BEeA);

contract ChainlinkOracleTest is Test {
    Source sourceZero = Source(address(0), 0);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    function testOracleWbtcUsdc() public {
        ChainlinkOracle oracle =
            new ChainlinkOracle( source(wBtcBtcFeed), source(btcUsdFeed), source(usdcUsdFeed), sourceZero, 8, 6);
        (, int256 firstBaseAnswer,,,) = wBtcBtcFeed.latestRoundData();
        (, int256 secondBaseAnswer,,,) = btcUsdFeed.latestRoundData();
        (, int256 quoteAnswer,,,) = usdcUsdFeed.latestRoundData();
        assertEq(
            oracle.price(),
            (uint256(firstBaseAnswer) * uint256(secondBaseAnswer) * 10 ** (36 + 8 + 6 - 8 - 8 - 8))
                / uint256(quoteAnswer)
        );
    }

    function testOracleUsdcWbtc() public {
        ChainlinkOracle oracle =
            new ChainlinkOracle(source(usdcUsdFeed),sourceZero,source(wBtcBtcFeed), source(btcUsdFeed), 6, 8);
        (, int256 baseAnswer,,,) = usdcUsdFeed.latestRoundData();
        (, int256 firstQuoteAnswer,,,) = wBtcBtcFeed.latestRoundData();
        (, int256 secondQuoteAnswer,,,) = btcUsdFeed.latestRoundData();
        assertEq(
            oracle.price(),
            (uint256(baseAnswer) * 10 ** (36 + 8 + 8 + 8 - 6 - 8))
                / (uint256(firstQuoteAnswer) * uint256(secondQuoteAnswer))
        );
    }

    function testOracleWbtcEth() public {
        ChainlinkOracle oracle =
            new ChainlinkOracle(source(wBtcBtcFeed), source(btcEthFeed), sourceZero, sourceZero, 8, 18);
        (, int256 firstBaseAnswer,,,) = wBtcBtcFeed.latestRoundData();
        (, int256 secondBaseAnswer,,,) = btcEthFeed.latestRoundData();
        assertEq(oracle.price(), (uint256(firstBaseAnswer) * uint256(secondBaseAnswer) * 10 ** (36 + 18 - 8 - 8 - 18)));
    }

    function testOracleStEthUsdc() public {
        ChainlinkOracle oracle =
            new ChainlinkOracle(source(stEthEthFeed), sourceZero, source(usdcEthFeed), sourceZero, 18, 6);
        (, int256 baseAnswer,,,) = stEthEthFeed.latestRoundData();
        (, int256 quoteAnswer,,,) = usdcEthFeed.latestRoundData();
        assertEq(oracle.price(), uint256(baseAnswer) * 10 ** (36 + 18 + 6 - 18 - 18) / uint256(quoteAnswer));
    }

    function testOracleEthUsd() public {
        ChainlinkOracle oracle = new ChainlinkOracle(source(ethUsdFeed),sourceZero,sourceZero,sourceZero, 18, 0);
        (, int256 expectedPrice,,,) = ethUsdFeed.latestRoundData();
        assertEq(oracle.price(), uint256(expectedPrice) * 10 ** (36 - 18 - 8));
    }

    function testOracleStEthEth() public {
        ChainlinkOracle oracle = new ChainlinkOracle(source(stEthEthFeed), sourceZero, sourceZero, sourceZero,18, 18);
        (, int256 expectedPrice,,,) = stEthEthFeed.latestRoundData();
        assertEq(oracle.price(), uint256(expectedPrice) * 10 ** (36 + 18 - 18 - 18));
        assertApproxEqRel(oracle.price(), 1e36, 0.01 ether);
    }

    function testOracleEthStEth() public {
        ChainlinkOracle oracle = new ChainlinkOracle(sourceZero,sourceZero,source(stEthEthFeed), sourceZero, 18, 18);
        (, int256 expectedPrice,,,) = stEthEthFeed.latestRoundData();
        assertEq(oracle.price(), 10 ** (36 + 18 + 18 - 18) / uint256(expectedPrice));
        assertApproxEqRel(oracle.price(), 1e36, 0.01 ether);
    }

    function testOracleUsdcUsd() public {
        ChainlinkOracle oracle = new ChainlinkOracle(source(usdcUsdFeed), sourceZero, sourceZero, sourceZero, 6, 0);
        assertApproxEqRel(oracle.price(), 1e36 / 1e6, 0.01 ether);
    }

    function testNegativeAnswer(int256 price) public {
        price = bound(price, type(int256).min, -1);
        ChainlinkAggregatorMock aggregator = new ChainlinkAggregatorMock();
        ChainlinkOracle oracle =
            new ChainlinkOracle(Source(address(aggregator),0), sourceZero, sourceZero, sourceZero, 18, 0);
        aggregator.setAnwser(price);
        vm.expectRevert(bytes(ErrorsLib.NEGATIVE_ANSWER));
        oracle.price();
    }

    function testSDaiEthOracle() public {
        uint256 sampleDecimals = 18;
        ChainlinkOracle oracle =
            new ChainlinkOracle(source(sDaiVault,sampleDecimals), source(daiEthFeed), sourceZero, sourceZero, 18, 18);
        (, int256 expectedPrice,,,) = daiEthFeed.latestRoundData();
        assertEq(
            oracle.price(),
            sDaiVault.convertToAssets(10**sampleDecimals) * uint256(expectedPrice) * 10 ** (36 + 18 + 0 - 18 - 18 - sampleDecimals)
        );
    }

    // Must change vault conversion sample to 1e4 or overflow in computing
    // SCALE_FACTOR. Should move to 512 bit multiplication.
    function testEthSDaiOracle() public {
        uint256 sampleDecimals = 18;
        ChainlinkOracle oracle =
            new ChainlinkOracle(sourceZero, sourceZero, source(sDaiVault,sampleDecimals), source(daiEthFeed), 18, 18);
        (, int256 expectedPrice,,,) = daiEthFeed.latestRoundData();
        assertEq(
            1e36 * 1e36 / oracle.price(),
            sDaiVault.convertToAssets(10**sampleDecimals) * uint256(expectedPrice) * 10 ** (36 + 18 + 0 - 18 - 18 - sampleDecimals)
        );
    }

    function testSDaiUsdcOracle() public {
        uint256 sampleDecimals = 18;
        ChainlinkOracle oracle =
        new ChainlinkOracle(source(sDaiVault,sampleDecimals), source(daiEthFeed), source(usdcEthFeed), sourceZero, 18, 6);
        (, int256 baseAnswer,,,) = daiEthFeed.latestRoundData();
        (, int256 quoteAnswer,,,) = usdcEthFeed.latestRoundData();
        assertEq(
            oracle.price(),
            sDaiVault.convertToAssets(10**sampleDecimals) * uint256(baseAnswer) * 10 ** (36 + 6 + 18 - 18 - 18 - sampleDecimals)
                / uint256(quoteAnswer)
        );
        // DAI has 12 more decimals than USDC.
        uint256 expectedPrice = 10 ** (36 - 12);
        // Admit a 50% interest gain before breaking this test.
        uint256 deviation = 0.5 ether;
        assertApproxEqRel(oracle.price(), expectedPrice, deviation);
    }

    // Had to set vault conversion sample to 1e14 or there is an overflow.
    // Should move to 512 bit multiplication.
    function testUsdcSDaiOracle() public {
        uint256 sampleDecimals = 14;
        ChainlinkOracle oracle =
        new ChainlinkOracle(source(usdcEthFeed), sourceZero, source(sDaiVault,sampleDecimals), source(daiEthFeed), 6, 18);
        (, int256 baseAnswer,,,) = daiEthFeed.latestRoundData();
        (, int256 quoteAnswer,,,) = usdcEthFeed.latestRoundData();
        assertEq(
            1e36 * 1e36 / oracle.price(),
            sDaiVault.convertToAssets(10**sampleDecimals) * uint256(baseAnswer) * 10 ** (36 + 6 + 18 - 18 - 18 - sampleDecimals)
                / uint256(quoteAnswer)
        );
        // DAI has 12 more decimals than USDC.
        uint256 expectedPrice = 10 ** (36 + 12);
        // Admit a 50% interest gain before breaking this test.
        uint256 deviation = 0.5 ether;
        assertApproxEqRel(oracle.price(), expectedPrice, deviation);
    }
}
