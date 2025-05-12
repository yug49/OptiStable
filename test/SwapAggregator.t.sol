// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {SwapAggregator} from "../src/SwapAggregator.sol";
//import {VaultManager} from "../src/VaultManager.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {IRouter} from "../lib/contracts/contracts/interfaces/IRouter.sol";
import {IFactoryRegistry} from "../lib/contracts/contracts/interfaces/factories/IFactoryRegistry.sol";
import {IMixedRouteQuoterV1} from "../src/interfaces/ICL/IMixedRouteQuoterV1.sol";
import {IV4Quoter} from "../lib/v4-periphery/src/interfaces/IV4Quoter.sol";
import {IQuoterV2} from "../lib/v3-periphery/contracts/interfaces/IQuoterV2.sol";

// Import constants
import {
    AERODROME_ROUTER,
    UNISWAP_V2_ROUTER,
    UNISWAP_V4_ROUTER,
    UNISWAP_V4_QUOTER,
    FACTORY_REGISTRY,
    USDC,
    USDT,
    EURC,
    DAI,
    TickSpacings,
    AERODROME_MULTI_ROUTER,
    UNISWAP_UNIVERSAL_ROUTER,
    UNISWAP_V3_QUOTER_V2
} from "../src/Constants.sol";

contract SwapAggregatorTest is Test, TickSpacings {
    SwapAggregator public swapAggregator;

    address USER = makeAddr("USER1");
    address public admin;

    IRouter router = IRouter(AERODROME_ROUTER);

    int24 constant VOLATILE_BITMASK = 4194304;
    int24 constant STABLE_BITMASK = 2097152;

    function setUp() public {
        admin = msg.sender;

        swapAggregator = new SwapAggregator(
            AERODROME_ROUTER,
            UNISWAP_V2_ROUTER,
            UNISWAP_V3_QUOTER_V2,
            UNISWAP_V4_ROUTER,
            UNISWAP_V4_QUOTER,
            FACTORY_REGISTRY,
            AERODROME_MULTI_ROUTER,
            UNISWAP_UNIVERSAL_ROUTER
        );

        deal(USDC, USER, 100000 * 1e6);

        vm.label(address(swapAggregator), "SwapAggregator");
        vm.label(USER, "User");
        vm.label(admin, "Admin");
        vm.label(USDC, "USDC");
        vm.label(USDT, "USDT");
        vm.label(EURC, "EURC");
        vm.label(DAI, "DAI");
        vm.label(FACTORY_REGISTRY, "FactoryRegistry");
        vm.label(AERODROME_ROUTER, "AerodromeRouter");
        vm.label(address(this), "SwapAggregatorTestContract");

        console.log("SwapAggregator deployed at:", address(swapAggregator));
    }

    function testQuoteExtactInputSingleV2() public {
        uint256 _amountIn = 1000 * 1e6;
        address _tokenIn = USDC;
        address _tokenOut = EURC;

        uint256 amountOut = IMixedRouteQuoterV1(AERODROME_MULTI_ROUTER).quoteExactInputSingleV2(
            IMixedRouteQuoterV1.QuoteExactInputSingleV2Params({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                amountIn: _amountIn,
                stable: true
            })
        );

        console.log("Aerodrome amount out:", amountOut);
    }

    function testQuoteExactInputSingleV3() public {
        uint256 _amountIn = 1000 * 1e6;
        address _tokenIn = USDC;
        address _tokenOut = EURC;
        int24[] memory tickSpacings = getAerodromeTickSpacings();

        uint256 amountMax;

        for (uint256 tickSpacing = 0; tickSpacing < tickSpacings.length; tickSpacing++) {
            console.log("tick spacing:", tickSpacings[tickSpacing]);
            (uint256 amountOut,,,) = IMixedRouteQuoterV1(AERODROME_MULTI_ROUTER).quoteExactInputSingleV3(
                IMixedRouteQuoterV1.QuoteExactInputSingleV3Params({
                    tokenIn: _tokenIn,
                    tokenOut: _tokenOut,
                    tickSpacing: tickSpacings[tickSpacing],
                    amountIn: _amountIn,
                    sqrtPriceLimitX96: 0
                })
            );
            console.log("Aerodrome amount out:", amountOut);
            if(amountOut > amountMax) {
                amountMax = amountOut;
            }
        }
        console.log("Max Aerodrome amount out:", amountMax);
    }

    function testGetAerodromeAmountOut() public {
        uint256 _amountIn = 1000 * 1e6;
        address _tokenIn = USDC;
        address _tokenOut = EURC;
        uint256 amountOut = 0;

        int24[] memory aerodromeTickSpacings = getAerodromeTickSpacings();

        for (uint256 i = 0; i < aerodromeTickSpacings.length; i++) {
            int24 tickSpacing = aerodromeTickSpacings[i];

            if (tickSpacing & VOLATILE_BITMASK != 0) {
                uint256 amountHere = IMixedRouteQuoterV1(AERODROME_MULTI_ROUTER).quoteExactInputSingleV2(
                    IMixedRouteQuoterV1.QuoteExactInputSingleV2Params({
                        tokenIn: _tokenIn,
                        tokenOut: _tokenOut,
                        amountIn: _amountIn,
                        stable: false
                    })
                );
                console.log("amount here:", amountHere);
                if (amountHere > amountOut) {
                    amountOut = amountHere;
                }
            } else if (tickSpacing & STABLE_BITMASK != 0) {
                uint256 amountHere = IMixedRouteQuoterV1(AERODROME_MULTI_ROUTER).quoteExactInputSingleV2(
                    IMixedRouteQuoterV1.QuoteExactInputSingleV2Params({
                        tokenIn: _tokenIn,
                        tokenOut: _tokenOut,
                        amountIn: _amountIn,
                        stable: true
                    })
                );
                console.log("amount here:", amountHere);
                if (amountHere > amountOut) {
                    amountOut = amountHere;
                }
            } else {
                /// the outputs of prior swaps become the inputs to subsequent ones
                (uint256 amountHere,,,) = IMixedRouteQuoterV1(AERODROME_MULTI_ROUTER).quoteExactInputSingleV3(
                    IMixedRouteQuoterV1.QuoteExactInputSingleV3Params({
                        tokenIn: _tokenIn,
                        tokenOut: _tokenOut,
                        tickSpacing: tickSpacing,
                        amountIn: _amountIn,
                        sqrtPriceLimitX96: 0
                    })
                );
                console.log("amount here:", amountHere);
                if (amountHere > amountOut) {
                    amountOut = amountHere;
                }
            }
        }

        vm.prank(USER);
        (uint256 actualAmountOut,) = swapAggregator.getAmountOutAerodrome(USDC, EURC, _amountIn, address(this));
        console.log("Aerodrome amount out:", actualAmountOut);
        assertEq(actualAmountOut, amountOut, "Aerodrome amount out is incorrect");
    }

    function testGetAmountOutUniswapV2() public {
        uint256 _amountIn = 1000 * 1e6;
        address _tokenIn = USDC;
        address _tokenOut = EURC;

        vm.prank(USER);
        (uint256 amountOut,) = swapAggregator.getAmountOutUniswapV2(_tokenIn, _tokenOut, _amountIn);
        console.log("Uniswap V2 amount out:", amountOut);
    }

    function testGetAmountOutUniswapV3() public {
        uint256 _amountIn = 1000 * 1e6;
        address _tokenIn = USDC;
        address _tokenOut = EURC;

        vm.prank(USER);
        (uint256 amountOut,) = swapAggregator.getAmountOutUniswapV3FromSpecificPool(_tokenIn, _tokenOut, _amountIn, 500);
        console.log("Uniswap V3 amount out:", amountOut);
    }

    function testGetAmountOutUniswapV4() public {
        uint256 _amountIn = 1000 * 1e6;
        address _tokenIn = USDC;
        address _tokenOut = EURC;
        uint24 fee = 200;
        int24 tickSpacing = 50;
        address hook = 0x5cd525c621AFCa515Bf58631D4733fbA7B72Aae4;

        vm.prank(USER);
        (uint256 amountOut,) = swapAggregator.getAmountOutUniswapV4FromSpecificPool(_tokenIn, _tokenOut, _amountIn, fee, tickSpacing, hook);
        console.log("Uniswap V4 amount out:", amountOut);
    }

    // function testGetAmountOutUniswapV2UsingUniversalRouter() public {
    //     uint256 _amountIn = 1000 * 1e6;
    //     address _tokenIn = USDC;
    //     address _tokenOut = EURC;

    //     vm.prank(USER);
    //     (uint256 amountOut,) = swapAggregator.getAmountOutUniswapUniversalRouter(_tokenIn, _tokenOut, _amountIn);
    //     console.log("Uniswap Universal Router amount out:", amountOut);
    // }

    // function getAmountOutUniswapV4(address _tokenIn, address _tokenOut, uint256 _amountIn)
    //     public
    //     virtual
    //     returns (uint256)
    // {
    //     if (_amountIn == 0) return 0;

    //     IV4Quoter quoter = IV4Quoter(UNISWAP_V4_QUOTER);

    //     // Create a PoolKey for the exact token pair
    //     PoolKey memory poolKey = _createPoolKey(_tokenIn, _tokenOut);

    //     try quoter.quoteExactInputSingle(
    //         IV4Quoter.QuoteExactSingleParams({
    //             poolKey: poolKey,
    //             zeroForOne: _tokenIn < _tokenOut,
    //             exactAmount: uint128(_amountIn),
    //             hookData: ""
    //         })
    //     ) returns (uint256 amountOut, uint256 gasEstimate) {
    //         return amountOut;
    //     } catch {
    //         return 0; // Return 0 if the call fails
    //     }
    // }

}
