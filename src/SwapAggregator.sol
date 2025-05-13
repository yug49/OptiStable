//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "./interfaces/IERC20.sol";
import {IRouter} from "../lib/contracts/contracts/interfaces/IRouter.sol";
import {IUniswapV2Router02} from "../lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IV4Router} from "../lib/v4-periphery/src/interfaces/IV4Router.sol";
import {IV4Quoter} from "../lib/v4-periphery/src/interfaces/IV4Quoter.sol";
import {PoolKey} from "../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import {Currency} from "../lib/v4-periphery/lib/v4-core/src/types/Currency.sol";
import {PathKey} from "../lib/v4-periphery/src/libraries/PathKey.sol";
import {IHooks} from "../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import {IFactoryRegistry} from "../lib/contracts/contracts/interfaces/factories/IFactoryRegistry.sol";
import {TickSpacings} from "./Constants.sol";
import {IMixedRouteQuoterV1} from "./interfaces/ICL/IMixedRouteQuoterV1.sol";
import {IUniswapXQuoter} from "./interfaces/IUniswapXQuoter.sol";
import {IUniswapXReactor} from "./interfaces/IUniswapXReactor.sol";
import {IQuoterV2} from "../lib/v3-periphery/contracts/interfaces/IQuoterV2.sol";
import {IUniversalRouter} from "./interfaces/IUniversalRouter.sol";
import {PoolKey} from "../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import {IHooks} from "../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import {Pool} from "./Pool.sol";
import {DEFAULT_FACTORY} from "./Constants.sol";
import {ISwapRouter} from "./interfaces/ISwapRouter.sol";
import {IV4Router} from "../lib/v4-periphery/src/interfaces/IV4Router.sol";
import {Commands} from "./helpers/Commands.sol";

/**
 * @title Swap Aggregartor to manage swap functionalities
 * @author Yug Agarwal
 * @dev finds the optimal route of swap
 */
contract SwapAggregator is TickSpacings {
    error SwapAggregator__NotOwner();
    error SwapAggregator__InvalidAmount();
    error SwapAggregator__InvalidRecipient();
    error SwapAggregator__InvalidTokenAddresses();
    error SwapAggregator__InvalidPoolFees();
    error SwapAggregator__InvalidArrayLengths();
    error SwapAggregator__InvalidTickSpacing();
    error SwapAggregator__PoolLocked();

    address public immutable i_aerodomeRouter;
    address public immutable i_swapRouter;
    address public immutable i_uniswapV2Router;
    address public immutable i_uniswapV4Router;
    address public immutable i_uniswapV4Quoter;
    address public immutable i_factoryRegistry;
    address public immutable i_aerodromeMultiRouter;
    address public immutable i_universalRouter;
    address public immutable i_uniswapV3Quoter;
    address public immutable pool;
    LockStatus private lockStatus;
    address public owner;
    uint256 private constant DEADLINE = 20 minutes;
    uint24 private constant DEFAULT_UNISWAP_FEE = 3000; //0.3 %
    int24 constant VOLATILE_BITMASK = 4194304;
    int24 constant STABLE_BITMASK = 2097152;

    enum SwapProtocol {
        AERODOME_V1_STABLE,
        AERODOME_V1_VOLATILE,
        AERODOME_V2,
        UNISWAP_X,
        UNISWAP_V2,
        UNISWAP_V3,
        UNISWAP_V4
    }

    enum LockStatus {
        UNLOCKED,
        LOCKED
    }

    event OptimalSwap(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountOut,
        address indexed recipient,
        SwapProtocol protocol
    );

    event UniswapV4SwapExecuted(uint256 amountOut, address indexed tokenIn, address indexed tokenOut, uint256 amountIn);

    modifier lock() {
        // Locking mechanism to prevent reentrancy
        if (lockStatus == LockStatus.LOCKED) {
            revert SwapAggregator__PoolLocked();
        }
        lockStatus = LockStatus.LOCKED;
        _;
        lockStatus = LockStatus.UNLOCKED;
    }

    /**
     * @param _aerodromeRouter Address of the Aerodrome router
     * @param _uniswapV2Router Address of the Uniswap V2 router
     * @param _uniswapV4Router Address of the Uniswap V4 router
     * @param _uniswapV4Quoter Address of the Uniswap V4 quoter
     * @param _factoryRegistry Address of the factory registry
     * @dev Constructor to initialize the contract with router addresses
     */
    constructor(
        address _aerodromeRouter,
        address _swapRouter,
        address _uniswapV2Router,
        address _uniswapV3Quoter,
        address _uniswapV4Router,
        address _uniswapV4Quoter,
        address _factoryRegistry,
        address _aerodromeMultiRouter,
        address _universalRouter,
        address _pool
    ) {
        i_aerodomeRouter = _aerodromeRouter;
        i_swapRouter = _swapRouter;
        i_uniswapV2Router = _uniswapV2Router;
        i_uniswapV4Router = _uniswapV4Router;
        i_uniswapV4Quoter = _uniswapV4Quoter;
        i_factoryRegistry = _factoryRegistry;
        i_aerodromeMultiRouter = _aerodromeMultiRouter;
        i_universalRouter = _universalRouter;
        i_uniswapV3Quoter = _uniswapV3Quoter;
        pool = _pool;

        // Set the owner of the contract to the deployer
        owner = msg.sender;
    }

    /**
     * @dev Gets optimal swap by analyzing all the pools of a token pair in aerodrome
     * @param _tokenIn token to swap from
     * @param _tokenOut token to swap to
     * @param _amountIn amount to swap
     * @param _recipient address of the recipient
     * @return amountOut amount received after the swap
     * @return protocol protocol used for the swap
     */
    function getAmountOutAerodrome(address _tokenIn, address _tokenOut, uint256 _amountIn, address _recipient)
        public
        returns (uint256 amountOut, SwapProtocol protocol, int24 tickSpacing)
    {
        if (_amountIn == 0) revert SwapAggregator__InvalidAmount();
        if (_recipient == address(0)) revert SwapAggregator__InvalidRecipient();
        if (_tokenIn == address(0) || _tokenOut == address(0)) revert SwapAggregator__InvalidTokenAddresses();
        if (_tokenIn == _tokenOut) revert SwapAggregator__InvalidTokenAddresses();

        int24[] memory aerodromeTickSpacings = getAerodromeTickSpacings();

        for (uint256 i = 0; i < aerodromeTickSpacings.length; i++) {
            int24 _tickSpacing = aerodromeTickSpacings[i];

            if (_tickSpacing & VOLATILE_BITMASK != 0) {
                uint256 amountHere = IMixedRouteQuoterV1(i_aerodromeMultiRouter).quoteExactInputSingleV2(
                    IMixedRouteQuoterV1.QuoteExactInputSingleV2Params({
                        tokenIn: _tokenIn,
                        tokenOut: _tokenOut,
                        amountIn: _amountIn,
                        stable: false
                    })
                );
                if (amountHere > amountOut) {
                    amountOut = amountHere;
                    protocol = SwapProtocol.AERODOME_V1_VOLATILE;
                    tickSpacing = 0;
                }
            }
            if (_tickSpacing & STABLE_BITMASK != 0) {
                uint256 amountHere = IMixedRouteQuoterV1(i_aerodromeMultiRouter).quoteExactInputSingleV2(
                    IMixedRouteQuoterV1.QuoteExactInputSingleV2Params({
                        tokenIn: _tokenIn,
                        tokenOut: _tokenOut,
                        amountIn: _amountIn,
                        stable: true
                    })
                );
                if (amountHere > amountOut) {
                    amountOut = amountHere;
                    protocol = SwapProtocol.AERODOME_V1_STABLE;
                    tickSpacing = 0;
                }
            }
            if (_tickSpacing & VOLATILE_BITMASK == 0 && _tickSpacing & STABLE_BITMASK == 0) {
                /// the outputs of prior swaps become the inputs to subsequent ones
                (uint256 amountHere,,,) = IMixedRouteQuoterV1(i_aerodromeMultiRouter).quoteExactInputSingleV3(
                    IMixedRouteQuoterV1.QuoteExactInputSingleV3Params({
                        tokenIn: _tokenIn,
                        tokenOut: _tokenOut,
                        tickSpacing: _tickSpacing,
                        amountIn: _amountIn,
                        sqrtPriceLimitX96: 0
                    })
                );
                if (amountHere > amountOut) {
                    amountOut = amountHere;
                    protocol = SwapProtocol.AERODOME_V2;
                    tickSpacing = _tickSpacing;
                }
            }
            i++;
        }
    }

    /**
     * @dev Swaps tokens using the Aerodrome V2 protocol
     * @param _tokenIn address of token to swap from
     * @param _tokenOut address of token to swap to
     * @param _amountIn amount of token to swap
     * @param _recipient address of the recipient
     * @param _tickSpacing tick spacing for the swap
     */
    function swapUsingAerodromeV2(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        address _recipient,
        int24 _tickSpacing
    ) public lock returns (uint256 amountOut) {
        if (_amountIn == 0) revert SwapAggregator__InvalidAmount();
        if (_recipient == address(0)) revert SwapAggregator__InvalidRecipient();
        if (_tokenIn == address(0) || _tokenOut == address(0)) revert SwapAggregator__InvalidTokenAddresses();
        if (_tokenIn == _tokenOut) revert SwapAggregator__InvalidTokenAddresses();
        if (_tickSpacing == 0) revert SwapAggregator__InvalidTickSpacing();

        uint256 amountBefore = IERC20(_tokenOut).balanceOf(_recipient);
        IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);
        IERC20(_tokenIn).approve(i_swapRouter, _amountIn);

        ISwapRouter(i_swapRouter).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                tickSpacing: _tickSpacing,
                recipient: _recipient,
                deadline: block.timestamp + DEADLINE,
                amountIn: _amountIn,
                amountOutMinimum: 0, // Set your desired minimum amount out
                sqrtPriceLimitX96: 0
            })
        );

        amountOut = IERC20(_tokenOut).balanceOf(_recipient) - amountBefore;

        emit OptimalSwap(_tokenIn, _tokenOut, amountOut, _recipient, SwapProtocol.AERODOME_V2);
    }

    /**
     * @dev Swaps tokens using the Aerodrome V2 stable pool
     * @param _tokenIn address of token to swap from
     * @param _tokenOut address of token to swap to
     * @param _amountIn amount of token to swap
     * @param _recipient address of the recipient
     */
    function swapUsingAerodromeV1Stable(address _tokenIn, address _tokenOut, uint256 _amountIn, address _recipient)
        public
        lock
        returns (uint256 amountOut)
    {
        if (_amountIn == 0) revert SwapAggregator__InvalidAmount();
        if (_recipient == address(0)) revert SwapAggregator__InvalidRecipient();
        if (_tokenIn == address(0) || _tokenOut == address(0)) revert SwapAggregator__InvalidTokenAddresses();
        if (_tokenIn == _tokenOut) revert SwapAggregator__InvalidTokenAddresses();

        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({from: _tokenIn, to: _tokenOut, stable: true, factory: DEFAULT_FACTORY});
        uint256 amountOutMin = 0; // Set your desired minimum amount out
        uint256 balanceBefore = IERC20(_tokenOut).balanceOf(_recipient);
        IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);
        IERC20(_tokenIn).approve(i_aerodomeRouter, _amountIn);
        IRouter(i_aerodomeRouter).swapExactTokensForTokens(
            _amountIn, amountOutMin, routes, _recipient, block.timestamp + DEADLINE
        );

        amountOut = IERC20(_tokenOut).balanceOf(_recipient) - balanceBefore;
        emit OptimalSwap(_tokenIn, _tokenOut, amountOut, _recipient, SwapProtocol.AERODOME_V1_STABLE);
    }

    /**
     * @dev Swaps tokens using the Aerodrome V2 volatile pool
     * @param _tokenIn address of token to swap from
     * @param _tokenOut address of token to swap to
     * @param _amountIn amount of token to swap
     * @param _recipient address of the recipient
     */
    function swapUsingAerodromeV1Volatile(address _tokenIn, address _tokenOut, uint256 _amountIn, address _recipient)
        public
        lock
        returns (uint256 amountOut)
    {
        if (_amountIn == 0) revert SwapAggregator__InvalidAmount();
        if (_recipient == address(0)) revert SwapAggregator__InvalidRecipient();
        if (_tokenIn == address(0) || _tokenOut == address(0)) revert SwapAggregator__InvalidTokenAddresses();
        if (_tokenIn == _tokenOut) revert SwapAggregator__InvalidTokenAddresses();

        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({from: _tokenIn, to: _tokenOut, stable: false, factory: DEFAULT_FACTORY});
        uint256 amountOutMin = 0; // Set your desired minimum amount out
        uint256 balanceBefore = IERC20(_tokenOut).balanceOf(_recipient);
        IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);
        IERC20(_tokenIn).approve(i_aerodomeRouter, _amountIn);
        IRouter(i_aerodomeRouter).swapExactTokensForTokens(
            _amountIn, amountOutMin, routes, _recipient, block.timestamp + DEADLINE
        );

        amountOut = IERC20(_tokenOut).balanceOf(_recipient) - balanceBefore;
        emit OptimalSwap(_tokenIn, _tokenOut, amountOut, _recipient, SwapProtocol.AERODOME_V1_VOLATILE);
    }

    /**
     * @dev Swaps tokens using the Uniswap Universal Router
     * @param tokenIn address of token to swap from
     * @param tokenOut address of token to swap to
     * @param amountIn amount of token to swap
     * @param recipient address of the recipient
     * @param poolFee fee tier for the pool
     * @param tickSpacing spacing between ticks in the pool
     * @param hook address of the hook contract
     * @param version version of the Uniswap router
     */
    function swapUsingUniswapUniversalRouter(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address recipient,
        uint24 poolFee,
        int24 tickSpacing,
        address hook,
        uint8 version
    ) public lock returns (uint256 amountOut) {
        if (amountIn == 0) revert SwapAggregator__InvalidAmount();
        if (recipient == address(0)) revert SwapAggregator__InvalidRecipient();
        if (tokenIn == address(0) || tokenOut == address(0)) revert SwapAggregator__InvalidTokenAddresses();
        if (tokenIn == tokenOut) revert SwapAggregator__InvalidTokenAddresses();

        // Transfer tokens from user to this contract
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Approve Universal Router to spend tokens
        IERC20(tokenIn).approve(i_universalRouter, amountIn);

        // Record starting balance to calculate amount received
        uint256 balanceBefore = IERC20(tokenOut).balanceOf(recipient);

        // Prepare command and input data based on version
        bytes memory commands;
        bytes[] memory inputs = new bytes[](1);

        if (version == 2) {
            // Uniswap V2 swap
            commands = abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));

            // Create path
            address[] memory path = new address[](2);
            path[0] = tokenIn;
            path[1] = tokenOut;

            // Pack input data
            inputs[0] = abi.encode(
                amountIn, // amountIn
                0, // amountOutMinimum
                path, // path
                recipient // recipient
            );
        } else if (version == 3) {
            // Uniswap V3 swap
            commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));

            // Pack input data
            inputs[0] = abi.encode(
                tokenIn, // tokenIn
                tokenOut, // tokenOut
                poolFee, // fee tier
                recipient, // recipient
                amountIn, // amountIn
                0 // amountOutMinimum
            );
        } else if (version == 4) {
            // Uniswap V4 swap
            commands = abi.encodePacked(bytes1(uint8(Commands.V4_SWAP)));

            // Determine currency order
            Currency currency0 = tokenIn < tokenOut ? Currency.wrap(tokenIn) : Currency.wrap(tokenOut);
            Currency currency1 = tokenIn < tokenOut ? Currency.wrap(tokenOut) : Currency.wrap(tokenIn);
            bool zeroForOne = tokenIn < tokenOut;

            // Create pool key
            PoolKey memory poolKey = PoolKey({
                currency0: currency0,
                currency1: currency1,
                fee: poolFee,
                tickSpacing: tickSpacing,
                hooks: IHooks(hook)
            });

            // Pack input data
            inputs[0] = abi.encode(
                poolKey, // poolKey
                zeroForOne, // zeroForOne
                true, // exactInput (true for exactInput)
                int256(int256(amountIn)), // amountSpecified (cast to int256)
                0, // sqrtPriceLimitX96 (0 = no price limit)
                "0x", // hookData
                recipient // recipient
            );
        } else {
            revert("SwapAggregator: Unsupported version");
        }

        // Execute swap through Universal Router
        IUniversalRouter(i_universalRouter).execute(commands, inputs, block.timestamp + DEADLINE);

        // Calculate amount received
        amountOut = IERC20(tokenOut).balanceOf(recipient) - balanceBefore;

        // Emit event
        SwapProtocol protocol;
        if (version == 2) protocol = SwapProtocol.UNISWAP_V2;
        else if (version == 3) protocol = SwapProtocol.UNISWAP_V3;
        else protocol = SwapProtocol.UNISWAP_V4;

        emit OptimalSwap(tokenIn, tokenOut, amountOut, recipient, protocol);

        return amountOut;
    }

    /**
     * @dev subgraph query
     *     {
     *       eurc_usdc: pools(
     *         where: {
     *           token0: "0x60a3e35cc302bfa44cb288bc5a4f316fdb1adb42",
     *           token1: "0x833589fcd6edb6e08f4c7c32d4f71b54bda02913"
     *         }
     *       ) {
     *         id
     *         feeTier
     *         tickSpacing
     *         hooks
     *       }
     *     }
     */
    /**
     * @dev Gets the optimal swap amount out from uniswap v4 by analazing all the pools of a given token pair
     * @param tokenIn address of token to swap from
     * @param tokenOut address of token to swap to
     * @param amountIn amount of token to swap
     * @param poolFees array of pool fees of all available pools of a given token pair in uniswap v3
     * @param tickSpacings array of tick spacings of all available pools of a given token pair in uniswap v3
     * @param hooks array of hooks of all available pools of a given token pair in uniswap v3
     * @return amountOut amount of token received after the swap
     * @return protocol protocol used for the swap
     */
    function getAmountOutUniswapV4(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint24[] memory poolFees,
        int24[] memory tickSpacings,
        address[] memory hooks
    ) public returns (uint256 amountOut, SwapProtocol protocol) {
        if (amountIn == 0) revert SwapAggregator__InvalidAmount();
        if (poolFees.length == 0) revert SwapAggregator__InvalidPoolFees();
        if (tokenIn == address(0) || tokenOut == address(0)) revert SwapAggregator__InvalidTokenAddresses();
        if (tokenIn == tokenOut) revert SwapAggregator__InvalidTokenAddresses();
        if (poolFees.length != tickSpacings.length || poolFees.length != hooks.length) {
            revert SwapAggregator__InvalidArrayLengths();
        }

        for (uint256 i = 0; i < poolFees.length; i++) {
            uint24 fee = poolFees[i];
            int24 tickSpacing = tickSpacings[i];
            address hook = hooks[i];
            (uint256 amountHere,) =
                getAmountOutUniswapV4FromSpecificPool(tokenIn, tokenOut, amountIn, fee, tickSpacing, hook);
            if (amountHere > amountOut) {
                amountOut = amountHere;
            }
        }

        protocol = SwapProtocol.UNISWAP_V4;
    }

    /**
     * @dev Gets the optimal swap amount out from uniswap v4 from a specific pool identified by the fee
     * @param tokenIn address of token to swap from
     * @param tokenOut address of token to swap to
     * @param amountIn amount of token to swap
     * @param fee fee for the swap
     * @param tickSpacing tick spacing for the pool
     * @param hook address of the hook to be used
     * @return amountOut amount of token received after the swap
     * @return protocol protocol used for the swap
     */
    function getAmountOutUniswapV4FromSpecificPool(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint24 fee,
        int24 tickSpacing,
        address hook
    ) public returns (uint256 amountOut, SwapProtocol protocol) {
        if (amountIn == 0) revert SwapAggregator__InvalidAmount();
        if (tokenIn == address(0) || tokenOut == address(0)) revert SwapAggregator__InvalidTokenAddresses();
        if (tokenIn == tokenOut) revert SwapAggregator__InvalidTokenAddresses();

        Currency currency0 = tokenIn < tokenOut ? Currency.wrap(tokenIn) : Currency.wrap(tokenOut);
        Currency currency1 = tokenIn < tokenOut ? Currency.wrap(tokenOut) : Currency.wrap(tokenIn);
        IHooks hooks = IHooks(hook);

        try IV4Quoter(i_uniswapV4Quoter).quoteExactInputSingle(
            IV4Quoter.QuoteExactSingleParams({
                poolKey: PoolKey({
                    currency0: currency0,
                    currency1: currency1,
                    fee: fee,
                    tickSpacing: tickSpacing,
                    hooks: hooks
                }),
                zeroForOne: tokenIn < tokenOut ? true : false,
                exactAmount: uint128(amountIn),
                hookData: ""
            })
        ) returns (uint256 result, uint256 /* gasEstimate */ ) {
            amountOut = result;
            protocol = SwapProtocol.UNISWAP_V4;
        } catch {
            // If the quote fails (e.g., pool doesn't exist), return 0
            amountOut = 0;
            protocol = SwapProtocol.UNISWAP_V4;
        }
    }

    /**
     * @dev Gets the optimal swap amount out from uniswap v3 by analyzing all the pools of a given token pair
     * @param tokenIn address of token to swap from
     * @param tokenOut address of token to swap to
     * @param amountIn amount of token to swap
     * @param poolFees array of pool fees of all available pools of a given token pair in uniswap v3
     * @return amountOut amount of token received after the swap
     * @return protocol protocol used for the swap
     */
    function getAmountOutUniswapV3(address tokenIn, address tokenOut, uint256 amountIn, uint24[] memory poolFees)
        public
        returns (uint256 amountOut, SwapProtocol protocol)
    {
        if (amountIn == 0) revert SwapAggregator__InvalidAmount();
        if (poolFees.length == 0) revert SwapAggregator__InvalidPoolFees();
        if (tokenIn == address(0) || tokenOut == address(0)) revert SwapAggregator__InvalidTokenAddresses();
        if (tokenIn == tokenOut) revert SwapAggregator__InvalidTokenAddresses();

        for (uint256 i = 0; i < poolFees.length; i++) {
            uint24 fee = poolFees[i];
            (uint256 amountHere,) = getAmountOutUniswapV3FromSpecificPool(tokenIn, tokenOut, amountIn, fee);
            if (amountHere > amountOut) {
                amountOut = amountHere;
            }
        }

        protocol = SwapProtocol.UNISWAP_V3;
    }

    /**
     * @dev Gets the optimal swap amount out from uniswap v3 from a specific pool identified by the fee
     * @param tokenIn address of token to swap from
     * @param tokenOut address of token to swap to
     * @param amountIn amount of token to swap
     * @param fee fee for the swap
     * @return amountOut amount of token received after the swap
     * @return protocol protocol used for the swap
     */
    function getAmountOutUniswapV3FromSpecificPool(address tokenIn, address tokenOut, uint256 amountIn, uint24 fee)
        public
        returns (uint256 amountOut, SwapProtocol protocol)
    {
        if (amountIn == 0) revert SwapAggregator__InvalidAmount();
        if (fee == 0) revert SwapAggregator__InvalidPoolFees();
        if (tokenIn == address(0) || tokenOut == address(0)) revert SwapAggregator__InvalidTokenAddresses();
        if (tokenIn == tokenOut) revert SwapAggregator__InvalidTokenAddresses();

        try IQuoterV2(i_uniswapV3Quoter).quoteExactInputSingle(
            IQuoterV2.QuoteExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                amountIn: amountIn,
                fee: fee,
                sqrtPriceLimitX96: 0 // No price limit (sqrtPriceLimitX96 = 0)
            })
        ) returns (
            uint256 result,
            uint160, /* sqrtPriceX96After */
            uint32, /* initializedTicksCrossed */
            uint256 /* gasEstimate */
        ) {
            amountOut = result;
            protocol = SwapProtocol.UNISWAP_V3;
        } catch {
            // If the quote fails (e.g., pool doesn't exist), return 0
            amountOut = 0;
            protocol = SwapProtocol.UNISWAP_V3;
        }
    }

    /**
     * @dev Gets the optimal swap amount out from uniswap v2
     * @param tokenIn address of token to swap from
     * @param tokenOut address of token to swap to
     * @param amountIn amount of token to swap
     * @return amountOut amount of token received after the swap
     * @return protocol protocol used for the swap
     */
    function getAmountOutUniswapV2(address tokenIn, address tokenOut, uint256 amountIn)
        public
        view
        returns (uint256 amountOut, SwapProtocol protocol)
    {
        if (amountIn == 0) revert SwapAggregator__InvalidAmount();
        if (tokenIn == address(0) || tokenOut == address(0)) revert SwapAggregator__InvalidTokenAddresses();
        if (tokenIn == tokenOut) revert SwapAggregator__InvalidTokenAddresses();

        address[] memory path = createPath(tokenIn, tokenOut);
        amountOut = IUniswapV2Router02(i_uniswapV2Router).getAmountsOut(amountIn, path)[path.length - 1];
        protocol = SwapProtocol.UNISWAP_V2;
    }

    /**
     * @dev Creates a path for the swap using uniswap v2
     * @param _tokenIn address of token to swap from
     * @param _tokenOut address of token to swap to
     */
    function createPath(address _tokenIn, address _tokenOut) internal pure returns (address[] memory path) {
        path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;
    }

    
}
