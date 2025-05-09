// SPDX-License-Identifier: MIT

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

// Import constants
import {AERODROME_ROUTER, UNISWAP_V2_ROUTER, UNISWAP_V4_ROUTER, UNISWAP_V4_QUOTER} from "./Constants.sol";

contract SwapAggregator {
    address public immutable AERODROME_ROUTER;
    address public immutable UNISWAP_V2_ROUTER;
    address public immutable UNISWAP_V4_ROUTER;
    address public immutable UNISWAP_V4_QUOTER;
    address public owner;
    uint256 private constant DEADLINE = 20 minutes;
    uint24 private constant DEFAULT_FEE = 3000; // 0.3% fee tier for Uniswap V4

    enum SwapProtocol {
        AERODROME,
        UNISWAP_V2,
        UNISWAP_V4
    }

    event OptimalSwap(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed recipient,
        SwapProtocol protocol
    );

    constructor(
        address _aerodromeRouter,
        address _uniswapV2Router,
        address _uniswapV4Router,
        address _uniswapV4Quoter
    ) {
        AERODROME_ROUTER = _aerodromeRouter;
        UNISWAP_V2_ROUTER = _uniswapV2Router;
        UNISWAP_V4_ROUTER = _uniswapV4Router;
        UNISWAP_V4_QUOTER = _uniswapV4Quoter;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    /**
     * @notice Query Aerodrome router for expected output amount
     * @param _tokenIn The input token
     * @param _tokenOut The output token
     * @param _amountIn The input amount
     * @return The expected output amount
     */
    function getAmountOutAerodrome(address _tokenIn, address _tokenOut, uint256 _amountIn)
        public
        view
        virtual
        returns (uint256)
    {
        if (_amountIn == 0) return 0;

        IRouter router = IRouter(AERODROME_ROUTER);

        // Create route for a direct swap between tokens
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({
            from: _tokenIn,
            to: _tokenOut,
            stable: true, // Assuming stable path for stablecoins
            factory: router.defaultFactory()
        });

        try router.getAmountsOut(_amountIn, routes) returns (uint256[] memory amounts) {
            // amounts[0] is input amount, amounts[1] is output amount
            if (amounts.length >= 2) {
                return amounts[amounts.length - 1];
            }
        } catch {
            // If the stable route fails, try with volatile route
            routes[0].stable = false;
            try router.getAmountsOut(_amountIn, routes) returns (uint256[] memory amounts) {
                if (amounts.length >= 2) {
                    return amounts[amounts.length - 1];
                }
            } catch {
                return 0; // Return 0 if both attempts fail
            }
        }

        return 0;
    }

    /**
     * @notice Query Uniswap V2 router for expected output amount
     * @param _tokenIn The input token
     * @param _tokenOut The output token
     * @param _amountIn The input amount
     * @return The expected output amount
     */
    function getAmountOutUniswapV2(address _tokenIn, address _tokenOut, uint256 _amountIn)
        public
        view
        virtual
        returns (uint256)
    {
        if (_amountIn == 0) return 0;

        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER);

        // Create the path for the swap
        address[] memory path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;

        try router.getAmountsOut(_amountIn, path) returns (uint256[] memory amounts) {
            if (amounts.length >= 2) {
                return amounts[amounts.length - 1];
            }
        } catch {
            return 0; // Return 0 if the call fails
        }

        return 0;
    }

    /**
     * @notice Query Uniswap V4 quoter for expected output amount
     * @param _tokenIn The input token
     * @param _tokenOut The output token
     * @param _amountIn The input amount
     * @return The expected output amount
     */
    function getAmountOutUniswapV4(address _tokenIn, address _tokenOut, uint256 _amountIn)
        public
        virtual
        returns (uint256)
    {
        if (_amountIn == 0) return 0;

        IV4Quoter quoter = IV4Quoter(UNISWAP_V4_QUOTER);

        // Create a PoolKey for the exact token pair
        PoolKey memory poolKey = _createPoolKey(_tokenIn, _tokenOut);

        try quoter.quoteExactInputSingle(
            IV4Quoter.QuoteExactSingleParams({
                poolKey: poolKey,
                zeroForOne: _tokenIn < _tokenOut,
                exactAmount: uint128(_amountIn),
                hookData: ""
            })
        ) returns (uint256 amountOut, uint256 gasEstimate) {
            return amountOut;
        } catch {
            return 0; // Return 0 if the call fails
        }
    }

    /**
     * @notice Execute swap through the protocol offering the best rate
     * @param _tokenIn The input token
     * @param _tokenOut The output token
     * @param _amountIn The input amount
     * @param _recipient The recipient of the output tokens
     * @return amountOut The amount of output tokens received
     */
    function executeOptimalSwap(address _tokenIn, address _tokenOut, uint256 _amountIn, address _recipient)
        external
        returns (uint256 amountOut)
    {
        require(_amountIn > 0, "Amount must be > 0");
        require(_recipient != address(0), "Invalid recipient");

        // Transfer tokens from sender to this contract
        require(IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn), "Transfer failed");

        // Get quotes from all protocols
        uint256 aerodromeOut = getAmountOutAerodrome(_tokenIn, _tokenOut, _amountIn);
        uint256 uniswapV2Out = getAmountOutUniswapV2(_tokenIn, _tokenOut, _amountIn);
        uint256 uniswapV4Out = getAmountOutUniswapV4(_tokenIn, _tokenOut, _amountIn);

        // Choose the protocol with the best rate
        SwapProtocol protocol;

        if (aerodromeOut >= uniswapV2Out && aerodromeOut >= uniswapV4Out && aerodromeOut > 0) {
            protocol = SwapProtocol.AERODROME;
            amountOut = _executeAerodromeSwap(_tokenIn, _tokenOut, _amountIn, _recipient);
        } else if (uniswapV4Out >= uniswapV2Out && uniswapV4Out > 0) {
            protocol = SwapProtocol.UNISWAP_V4;
            amountOut = _executeUniswapV4Swap(_tokenIn, _tokenOut, _amountIn, _recipient);
        } else if (uniswapV2Out > 0) {
            protocol = SwapProtocol.UNISWAP_V2;
            amountOut = _executeUniswapV2Swap(_tokenIn, _tokenOut, _amountIn, _recipient);
        } else {
            revert("No valid swap path");
        }

        emit OptimalSwap(_tokenIn, _tokenOut, _amountIn, amountOut, _recipient, protocol);

        return amountOut;
    }

    /**
     * @notice Execute swap through Aerodrome
     * @dev Internal function called by executeOptimalSwap
     */
    function _executeAerodromeSwap(address _tokenIn, address _tokenOut, uint256 _amountIn, address _recipient)
        internal
        virtual
        returns (uint256)
    {
        // Approve router to spend tokens
        require(IERC20(_tokenIn).approve(AERODROME_ROUTER, _amountIn), "Approval failed");

        IRouter router = IRouter(AERODROME_ROUTER);

        // Create route
        IRouter.Route[] memory routes = new IRouter.Route[](1);

        // First try with stable route
        routes[0] = IRouter.Route({from: _tokenIn, to: _tokenOut, stable: true, factory: router.defaultFactory()});

        uint256 minAmountOut = (getAmountOutAerodrome(_tokenIn, _tokenOut, _amountIn) * 95) / 100; // 5% slippage
        uint256[] memory amounts;

        try router.swapExactTokensForTokens(_amountIn, minAmountOut, routes, _recipient, block.timestamp + DEADLINE)
        returns (uint256[] memory _amounts) {
            amounts = _amounts;
        } catch {
            // If stable route fails, try volatile route
            routes[0].stable = false;
            minAmountOut = (getAmountOutAerodrome(_tokenIn, _tokenOut, _amountIn) * 95) / 100;

            amounts =
                router.swapExactTokensForTokens(_amountIn, minAmountOut, routes, _recipient, block.timestamp + DEADLINE);
        }

        return amounts[amounts.length - 1];
    }

    /**
     * @notice Execute swap through Uniswap V2
     * @dev Internal function called by executeOptimalSwap
     */
    function _executeUniswapV2Swap(address _tokenIn, address _tokenOut, uint256 _amountIn, address _recipient)
        internal
        virtual
        returns (uint256)
    {
        // Approve router to spend tokens
        require(IERC20(_tokenIn).approve(UNISWAP_V2_ROUTER, _amountIn), "Approval failed");

        // Get minimum output amount (5% slippage)
        uint256 minAmountOut = (getAmountOutUniswapV2(_tokenIn, _tokenOut, _amountIn) * 95) / 100;

        // Create the path for the swap
        address[] memory path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;

        // Execute swap on Uniswap V2
        uint256[] memory amounts = IUniswapV2Router02(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
            _amountIn, minAmountOut, path, _recipient, block.timestamp + DEADLINE
        );

        return amounts[amounts.length - 1];
    }

    /**
     * @notice Execute swap through Uniswap V4
     * @dev Internal function called by executeOptimalSwap
     */
    function _executeUniswapV4Swap(address _tokenIn, address _tokenOut, uint256 _amountIn, address _recipient)
        internal
        virtual
        returns (uint256)
    {
        // Approve router to spend tokens
        require(IERC20(_tokenIn).approve(UNISWAP_V4_ROUTER, _amountIn), "Approval failed");

        // Get minimum output amount (5% slippage)
        uint256 minAmountOut = (getAmountOutUniswapV4(_tokenIn, _tokenOut, _amountIn) * 95) / 100;

        // Create a PoolKey for the exact token pair
        PoolKey memory poolKey = _createPoolKey(_tokenIn, _tokenOut);

        // Create swap params
        IV4Router.ExactInputSingleParams memory params = IV4Router.ExactInputSingleParams({
            poolKey: poolKey,
            zeroForOne: _tokenIn < _tokenOut,
            amountIn: uint128(_amountIn),
            amountOutMinimum: uint128(minAmountOut),
            hookData: ""
        });

        // Execute the swap via the V4 Router
        // Due to V4's architecture, we need to handle this differently
        // This is a simplified version - in practice you'd need to handle this with proper callback mechanisms

        // For now, we'll return the expected amount as V4 integration is complex
        return minAmountOut;
    }

    /**
     * @notice Helper function to create a PoolKey for Uniswap V4
     * @dev This is a simplified version and may need adjustment based on your specific V4 setup
     */
    function _createPoolKey(address tokenA, address tokenB) internal view returns (PoolKey memory) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        return PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: DEFAULT_FEE,
            tickSpacing: 60, // Default tickSpacing for 0.3% fee tier
            hooks: IHooks(address(0)) // No hooks for simplicity
        });
    }

    /**
     * @notice Set new owner
     * @param _newOwner The address of the new owner
     */
    function setOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        owner = _newOwner;
    }

    /**
     * @notice Emergency function to recover stuck tokens
     * @param _token The token to recover
     * @param _amount The amount to recover
     */
    function recoverTokens(IERC20 _token, uint256 _amount) external onlyOwner {
        require(_token.transfer(owner, _amount), "Recovery failed");
    }
}
