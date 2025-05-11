// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.20;

// import {IERC20} from "./interfaces/IERC20.sol";
// import {IRouter} from "../lib/contracts/contracts/interfaces/IRouter.sol";
// import {IUniswapV2Router02} from "../lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
// import {IV4Router} from "../lib/v4-periphery/src/interfaces/IV4Router.sol";
// import {IV4Quoter} from "../lib/v4-periphery/src/interfaces/IV4Quoter.sol";
// import {PoolKey} from "../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";
// import {Currency} from "../lib/v4-periphery/lib/v4-core/src/types/Currency.sol";
// import {PathKey} from "../lib/v4-periphery/src/libraries/PathKey.sol";
// import {IHooks} from "../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
// import {IFactoryRegistry} from "../lib/contracts/contracts/interfaces/factories/IFactoryRegistry.sol";

// // Import constants
// import {AERODROME_ROUTER, UNISWAP_V2_ROUTER, UNISWAP_V4_ROUTER, UNISWAP_V4_QUOTER} from "./Constants.sol";

// contract SwapAggregator {
//     address public immutable AERODROME_ROUTER;
//     address public immutable UNISWAP_V2_ROUTER;
//     address public immutable UNISWAP_V4_ROUTER;
//     address public immutable UNISWAP_V4_QUOTER;
//     address public immutable FACTORY_REGISTRY;
//     address public owner;
//     uint256 private constant DEADLINE = 20 minutes;
//     uint24 private constant DEFAULT_FEE = 3000; // 0.3% fee tier for Uniswap V4

//     enum SwapProtocol {
//         AERODROME,
//         UNISWAP_V2,
//         UNISWAP_V4
//     }

//     event OptimalSwap(
//         address indexed tokenIn,
//         address indexed tokenOut,
//         uint256 amountIn,
//         uint256 amountOut,
//         address indexed recipient,
//         SwapProtocol protocol
//     );

//     constructor(
//         address _aerodromeRouter,
//         address _uniswapV2Router,
//         address _uniswapV4Router,
//         address _uniswapV4Quoter,
//         address _factoryRegistry
//     ) {
//         AERODROME_ROUTER = _aerodromeRouter;
//         UNISWAP_V2_ROUTER = _uniswapV2Router;
//         UNISWAP_V4_ROUTER = _uniswapV4Router;
//         UNISWAP_V4_QUOTER = _uniswapV4Quoter;
//         FACTORY_REGISTRY = _factoryRegistry;
//         owner = msg.sender;
//     }

//     modifier onlyOwner() {
//         require(msg.sender == owner, "Not authorized");
//         _;
//     }

//     /**
//      * @notice Query Aerodrome router for expected output amount
//      * @param _tokenIn The input token
//      * @param _tokenOut The output token
//      * @param _amountIn The input amount
//      * @return The expected output amount
//      */
//     function getAmountOutAerodrome(address _tokenIn, address _tokenOut, uint256 _amountIn)
//         public
//         view
//         virtual
//         returns (uint256)
//     {
//         if (_amountIn == 0) return 0;

//         IRouter router = IRouter(AERODROME_ROUTER);

//         // Create route for a direct swap between tokens
//         IRouter.Route[] memory routes = new IRouter.Route[](1);
//         routes[0] = IRouter.Route({
//             from: _tokenIn,
//             to: _tokenOut,
//             stable: true, // Assuming stable path for stablecoins
//             factory: router.defaultFactory()
//         });

//         try router.getAmountsOut(_amountIn, routes) returns (uint256[] memory amounts) {
//             // amounts[0] is input amount, amounts[1] is output amount
//             if (amounts.length >= 2) {
//                 return amounts[amounts.length - 1];
//             }
//         } catch {
//             // If the stable route fails, try with volatile route
//             routes[0].stable = false;
//             try router.getAmountsOut(_amountIn, routes) returns (uint256[] memory amounts) {
//                 if (amounts.length >= 2) {
//                     return amounts[amounts.length - 1];
//                 }
//             } catch {
//                 return 0; // Return 0 if both attempts fail
//             }
//         }

//         return 0;
//     }

//     /**
//      * @notice Query Aerodrome router for expected output amount with custom factory
//      * @param _tokenIn The input token
//      * @param _tokenOut The output token
//      * @param _amountIn The input amount
//      * @param _factory The factory address to use
//      * @param _stable Whether to use stable or volatile pool
//      * @return The expected output amount
//      */
//     function getAmountOutAerodromeWithFactory(
//         address _tokenIn,
//         address _tokenOut,
//         uint256 _amountIn,
//         address _factory,
//         bool _stable
//     ) public view returns (uint256) {
//         if (_amountIn == 0) return 0;

//         IRouter router = IRouter(AERODROME_ROUTER);

//         // Create route for a direct swap between tokens with specified factory
//         IRouter.Route[] memory routes = new IRouter.Route[](1);
//         routes[0] = IRouter.Route({from: _tokenIn, to: _tokenOut, stable: _stable, factory: _factory});

//         try router.getAmountsOut(_amountIn, routes) returns (uint256[] memory amounts) {
//             if (amounts.length >= 2) {
//                 return amounts[amounts.length - 1];
//             }
//         } catch {
//             return 0; // Return 0 if the call fails
//         }

//         return 0;
//     }

//     /**
//      * @notice Query Uniswap V2 router for expected output amount
//      * @param _tokenIn The input token
//      * @param _tokenOut The output token
//      * @param _amountIn The input amount
//      * @return The expected output amount
//      */
//     function getAmountOutUniswapV2(address _tokenIn, address _tokenOut, uint256 _amountIn)
//         public
//         view
//         virtual
//         returns (uint256)
//     {
//         if (_amountIn == 0) return 0;

//         IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER);

//         // Create the path for the swap
//         address[] memory path = new address[](2);
//         path[0] = _tokenIn;
//         path[1] = _tokenOut;

//         try router.getAmountsOut(_amountIn, path) returns (uint256[] memory amounts) {
//             if (amounts.length >= 2) {
//                 return amounts[amounts.length - 1];
//             }
//         } catch {
//             return 0; // Return 0 if the call fails
//         }

//         return 0;
//     }

//     /**
//      * @notice Query Uniswap V4 quoter for expected output amount
//      * @param _tokenIn The input token
//      * @param _tokenOut The output token
//      * @param _amountIn The input amount
//      * @return The expected output amount
//      */
//     function getAmountOutUniswapV4(address _tokenIn, address _tokenOut, uint256 _amountIn)
//         public
//         virtual
//         returns (uint256)
//     {
//         if (_amountIn == 0) return 0;

//         IV4Quoter quoter = IV4Quoter(UNISWAP_V4_QUOTER);

//         // Create a PoolKey for the exact token pair
//         PoolKey memory poolKey = _createPoolKey(_tokenIn, _tokenOut);

//         try quoter.quoteExactInputSingle(
//             IV4Quoter.QuoteExactSingleParams({
//                 poolKey: poolKey,
//                 zeroForOne: _tokenIn < _tokenOut,
//                 exactAmount: uint128(_amountIn),
//                 hookData: ""
//             })
//         ) returns (uint256 amountOut, uint256 gasEstimate) {
//             return amountOut;
//         } catch {
//             return 0; // Return 0 if the call fails
//         }
//     }

//     /**
//      * @notice Execute swap through the protocol offering the best rate
//      * @param _tokenIn The input token
//      * @param _tokenOut The output token
//      * @param _amountIn The input amount
//      * @param _recipient The recipient of the output tokens
//      * @return amountOut The amount of output tokens received
//      */
//     function executeOptimalSwap(address _tokenIn, address _tokenOut, uint256 _amountIn, address _recipient)
//         external
//         returns (uint256 amountOut)
//     {
//         require(_amountIn > 0, "Amount must be > 0");
//         require(_recipient != address(0), "Invalid recipient");

//         // Transfer tokens from sender to this contract
//         require(IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn), "Transfer failed");

//         // Get quotes from standard protocols (basic routes)
//         uint256 aerodromeOut = getAmountOutAerodrome(_tokenIn, _tokenOut, _amountIn);
//         uint256 uniswapV2Out = getAmountOutUniswapV2(_tokenIn, _tokenOut, _amountIn);
//         uint256 uniswapV4Out = getAmountOutUniswapV4(_tokenIn, _tokenOut, _amountIn);

//         // Prepare to track best options
//         uint256 bestAmountOut = 0;
//         address bestFactory = address(0);
//         bool bestIsStable = false;
//         SwapProtocol bestProtocol = SwapProtocol.AERODROME;

//         // Dynamically discover and check all available factories from the registry
//         address[] memory allFactories = _getApprovedFactories();

//         // Check each factory with both stable and volatile options
//         for (uint256 i = 0; i < allFactories.length; i++) {
//             address factory = allFactories[i];

//             // Check stable route
//             uint256 factoryStableOut = getAmountOutAerodromeWithFactory(_tokenIn, _tokenOut, _amountIn, factory, true);
//             if (factoryStableOut > bestAmountOut) {
//                 bestAmountOut = factoryStableOut;
//                 bestFactory = factory;
//                 bestIsStable = true;
//                 bestProtocol = SwapProtocol.AERODROME;
//             }

//             // Check volatile route
//             uint256 factoryVolatileOut =
//                 getAmountOutAerodromeWithFactory(_tokenIn, _tokenOut, _amountIn, factory, false);
//             if (factoryVolatileOut > bestAmountOut) {
//                 bestAmountOut = factoryVolatileOut;
//                 bestFactory = factory;
//                 bestIsStable = false;
//                 bestProtocol = SwapProtocol.AERODROME;
//             }
//         }

//         // Check standard Aerodrome route (using default factory) if not already checked
//         // We keep this check separate as it might have been optimized differently
//         if (aerodromeOut > bestAmountOut) {
//             bestAmountOut = aerodromeOut;
//             bestFactory = IRouter(AERODROME_ROUTER).defaultFactory(); // Use default factory
//             bestIsStable = true; // Default to stable for stablecoins
//             bestProtocol = SwapProtocol.AERODROME;
//         }

//         // Check Uniswap V4
//         if (uniswapV4Out > bestAmountOut) {
//             bestAmountOut = uniswapV4Out;
//             bestFactory = address(0); // Not applicable for Uniswap
//             bestProtocol = SwapProtocol.UNISWAP_V4;
//         }

//         // Check Uniswap V2
//         if (uniswapV2Out > bestAmountOut) {
//             bestAmountOut = uniswapV2Out;
//             bestFactory = address(0); // Not applicable for Uniswap
//             bestProtocol = SwapProtocol.UNISWAP_V2;
//         }

//         // Execute swap using best route
//         if (bestAmountOut == 0) {
//             revert("No valid swap path");
//         }

//         if (bestProtocol == SwapProtocol.AERODROME) {
//             // Check if we're using a non-standard path
//             IRouter router = IRouter(AERODROME_ROUTER);
//             address defaultFactory = router.defaultFactory();

//             if (bestFactory != defaultFactory || bestIsStable == false) {
//                 // If using a custom factory or volatile route
//                 amountOut = this.executeAerodromeSwapWithFactory(
//                     _tokenIn, _tokenOut, _amountIn, _recipient, bestFactory, bestIsStable
//                 );
//             } else {
//                 // Standard Aerodrome route
//                 amountOut = _executeAerodromeSwap(_tokenIn, _tokenOut, _amountIn, _recipient);
//             }
//         } else if (bestProtocol == SwapProtocol.UNISWAP_V4) {
//             amountOut = _executeUniswapV4Swap(_tokenIn, _tokenOut, _amountIn, _recipient);
//         } else if (bestProtocol == SwapProtocol.UNISWAP_V2) {
//             amountOut = _executeUniswapV2Swap(_tokenIn, _tokenOut, _amountIn, _recipient);
//         }

//         emit OptimalSwap(_tokenIn, _tokenOut, _amountIn, amountOut, _recipient, bestProtocol);

//         return amountOut;
//     }

//     /**
//      * @notice Execute swap through Aerodrome
//      * @dev Internal function called by executeOptimalSwap
//      */
//     function _executeAerodromeSwap(address _tokenIn, address _tokenOut, uint256 _amountIn, address _recipient)
//         internal
//         virtual
//         returns (uint256)
//     {
//         // Approve router to spend tokens
//         require(IERC20(_tokenIn).approve(AERODROME_ROUTER, _amountIn), "Approval failed");

//         IRouter router = IRouter(AERODROME_ROUTER);

//         // Create route
//         IRouter.Route[] memory routes = new IRouter.Route[](1);

//         // First try with stable route
//         routes[0] = IRouter.Route({from: _tokenIn, to: _tokenOut, stable: true, factory: router.defaultFactory()});

//         uint256 minAmountOut = (getAmountOutAerodrome(_tokenIn, _tokenOut, _amountIn) * 95) / 100; // 5% slippage
//         uint256[] memory amounts;

//         try router.swapExactTokensForTokens(_amountIn, minAmountOut, routes, _recipient, block.timestamp + DEADLINE)
//         returns (uint256[] memory _amounts) {
//             amounts = _amounts;
//         } catch {
//             // If stable route fails, try volatile route
//             routes[0].stable = false;
//             minAmountOut = (getAmountOutAerodrome(_tokenIn, _tokenOut, _amountIn) * 95) / 100;

//             amounts =
//                 router.swapExactTokensForTokens(_amountIn, minAmountOut, routes, _recipient, block.timestamp + DEADLINE);
//         }

//         return amounts[amounts.length - 1];
//     }

//     /**
//      * @notice Execute swap through Aerodrome with custom factory
//      * @param _tokenIn The input token
//      * @param _tokenOut The output token
//      * @param _amountIn The input amount
//      * @param _recipient The recipient of the output tokens
//      * @param _factory The factory address to use
//      * @param _stable Whether to use stable or volatile pool
//      * @return The amount of output tokens received
//      */
//     function executeAerodromeSwapWithFactory(
//         address _tokenIn,
//         address _tokenOut,
//         uint256 _amountIn,
//         address _recipient,
//         address _factory,
//         bool _stable
//     ) external returns (uint256) {
//         require(_amountIn > 0, "Amount must be > 0");
//         require(_recipient != address(0), "Invalid recipient");

//         // Transfer tokens from sender to this contract
//         require(IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn), "Transfer failed");

//         // Approve router to spend tokens
//         require(IERC20(_tokenIn).approve(AERODROME_ROUTER, _amountIn), "Approval failed");

//         IRouter router = IRouter(AERODROME_ROUTER);

//         // Create route with specified factory and stability
//         IRouter.Route[] memory routes = new IRouter.Route[](1);
//         routes[0] = IRouter.Route({from: _tokenIn, to: _tokenOut, stable: _stable, factory: _factory});

//         // Get minimum output amount (5% slippage)
//         uint256 minAmountOut =
//             (getAmountOutAerodromeWithFactory(_tokenIn, _tokenOut, _amountIn, _factory, _stable) * 95) / 100;

//         // Execute the swap
//         uint256[] memory amounts =
//             router.swapExactTokensForTokens(_amountIn, minAmountOut, routes, _recipient, block.timestamp + DEADLINE);

//         emit OptimalSwap(
//             _tokenIn, _tokenOut, _amountIn, amounts[amounts.length - 1], _recipient, SwapProtocol.AERODROME
//         );

//         return amounts[amounts.length - 1];
//     }

//     /**
//      * @notice Execute swap through Uniswap V2
//      * @dev Internal function called by executeOptimalSwap
//      */
//     function _executeUniswapV2Swap(address _tokenIn, address _tokenOut, uint256 _amountIn, address _recipient)
//         internal
//         virtual
//         returns (uint256)
//     {
//         // Approve router to spend tokens
//         require(IERC20(_tokenIn).approve(UNISWAP_V2_ROUTER, _amountIn), "Approval failed");

//         // Get minimum output amount (5% slippage)
//         uint256 minAmountOut = (getAmountOutUniswapV2(_tokenIn, _tokenOut, _amountIn) * 95) / 100;

//         // Create the path for the swap
//         address[] memory path = new address[](2);
//         path[0] = _tokenIn;
//         path[1] = _tokenOut;

//         // Execute swap on Uniswap V2
//         uint256[] memory amounts = IUniswapV2Router02(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
//             _amountIn, minAmountOut, path, _recipient, block.timestamp + DEADLINE
//         );

//         return amounts[amounts.length - 1];
//     }

//     /**
//      * @notice Execute swap through Uniswap V4
//      * @dev Internal function called by executeOptimalSwap
//      */
//     function _executeUniswapV4Swap(address _tokenIn, address _tokenOut, uint256 _amountIn, address _recipient)
//         internal
//         virtual
//         returns (uint256)
//     {
//         // Approve router to spend tokens
//         require(IERC20(_tokenIn).approve(UNISWAP_V4_ROUTER, _amountIn), "Approval failed");

//         // Get minimum output amount (5% slippage)
//         uint256 minAmountOut = (getAmountOutUniswapV4(_tokenIn, _tokenOut, _amountIn) * 95) / 100;

//         // Create a PoolKey for the exact token pair
//         PoolKey memory poolKey = _createPoolKey(_tokenIn, _tokenOut);

//         // Create swap params
//         IV4Router.ExactInputSingleParams memory params = IV4Router.ExactInputSingleParams({
//             poolKey: poolKey,
//             zeroForOne: _tokenIn < _tokenOut,
//             amountIn: uint128(_amountIn),
//             amountOutMinimum: uint128(minAmountOut),
//             hookData: ""
//         });

//         // Execute the swap via the V4 Router
//         // Due to V4's architecture, we need to handle this differently
//         // This is a simplified version - in practice you'd need to handle this with proper callback mechanisms

//         // For now, we'll return the expected amount as V4 integration is complex
//         return minAmountOut;
//     }

//     /**
//      * @notice Helper function to create a PoolKey for Uniswap V4
//      * @dev This is a simplified version and may need adjustment based on your specific V4 setup
//      */
//     function _createPoolKey(address tokenA, address tokenB) internal view returns (PoolKey memory) {
//         (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

//         return PoolKey({
//             currency0: Currency.wrap(token0),
//             currency1: Currency.wrap(token1),
//             fee: DEFAULT_FEE,
//             tickSpacing: 60, // Default tickSpacing for 0.3% fee tier
//             hooks: IHooks(address(0)) // No hooks for simplicity
//         });
//     }

//     /**
//      * @notice Execute swap through the protocol offering the best rate, including custom Aerodrome factories
//      * @param _tokenIn The input token
//      * @param _tokenOut The output token
//      * @param _amountIn The input amount
//      * @param _recipient The recipient of the output tokens
//      * @param _aerodromeFactories Array of factory addresses to check for Aerodrome
//      * @param _stableOptions Array of stability flags corresponding to factories
//      * @return amountOut The amount of output tokens received
//      */
//     function executeOptimalSwapWithFactories(
//         address _tokenIn,
//         address _tokenOut,
//         uint256 _amountIn,
//         address _recipient,
//         address[] calldata _aerodromeFactories,
//         bool[] calldata _stableOptions
//     ) external returns (uint256 amountOut) {
//         require(_amountIn > 0, "Amount must be > 0");
//         require(_recipient != address(0), "Invalid recipient");
//         require(_aerodromeFactories.length == _stableOptions.length, "Array length mismatch");

//         // Transfer tokens from sender to this contract
//         require(IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn), "Transfer failed");

//         // Get quotes from standard protocols
//         uint256 aerodromeOut = getAmountOutAerodrome(_tokenIn, _tokenOut, _amountIn);
//         uint256 uniswapV2Out = getAmountOutUniswapV2(_tokenIn, _tokenOut, _amountIn);
//         uint256 uniswapV4Out = getAmountOutUniswapV4(_tokenIn, _tokenOut, _amountIn);

//         // Track the best option
//         uint256 bestAmountOut = 0;
//         address bestFactory = address(0);
//         bool bestIsStable = false;
//         SwapProtocol bestProtocol = SwapProtocol.AERODROME;
//         uint256 bestFactoryIndex = 0;
//         bool isCustomFactory = false;

//         // Process provided factories
//         for (uint256 i = 0; i < _aerodromeFactories.length; i++) {
//             uint256 customOut = getAmountOutAerodromeWithFactory(
//                 _tokenIn, _tokenOut, _amountIn, _aerodromeFactories[i], _stableOptions[i]
//             );

//             if (customOut > bestAmountOut) {
//                 bestAmountOut = customOut;
//                 bestFactory = _aerodromeFactories[i];
//                 bestIsStable = _stableOptions[i];
//                 bestProtocol = SwapProtocol.AERODROME;
//                 bestFactoryIndex = i;
//                 isCustomFactory = true;
//             }
//         }

//         // Check CLAMMs and other potential AMM sources not explicitly provided
//         // Example: Check CLAMM factory
//         address clammFactory = 0x420000000000000000000000000000000000000c; // Replace with actual CLAMM factory

//         // Check if the CLAMM factory isn't already in the provided factories
//         bool clammAlreadyChecked = false;
//         for (uint256 i = 0; i < _aerodromeFactories.length; i++) {
//             if (_aerodromeFactories[i] == clammFactory) {
//                 clammAlreadyChecked = true;
//                 break;
//             }
//         }

//         // Only check CLAMM factory if it wasn't already in the provided factories
//         if (!clammAlreadyChecked) {
//             try getAmountOutAerodromeWithFactory(_tokenIn, _tokenOut, _amountIn, clammFactory, true) returns (
//                 uint256 clammStableOut
//             ) {
//                 if (clammStableOut > bestAmountOut) {
//                     bestAmountOut = clammStableOut;
//                     bestFactory = clammFactory;
//                     bestIsStable = true;
//                     bestProtocol = SwapProtocol.AERODROME;
//                     isCustomFactory = true;
//                 }
//             } catch {}

//             try getAmountOutAerodromeWithFactory(_tokenIn, _tokenOut, _amountIn, clammFactory, false) returns (
//                 uint256 clammVolatileOut
//             ) {
//                 if (clammVolatileOut > bestAmountOut) {
//                     bestAmountOut = clammVolatileOut;
//                     bestFactory = clammFactory;
//                     bestIsStable = false;
//                     bestProtocol = SwapProtocol.AERODROME;
//                     isCustomFactory = true;
//                 }
//             } catch {}
//         }

//         // Compare with standard protocol outputs
//         if (aerodromeOut > bestAmountOut) {
//             bestAmountOut = aerodromeOut;
//             isCustomFactory = false;
//             bestProtocol = SwapProtocol.AERODROME;
//         }

//         if (uniswapV4Out > bestAmountOut) {
//             bestAmountOut = uniswapV4Out;
//             isCustomFactory = false;
//             bestProtocol = SwapProtocol.UNISWAP_V4;
//         }

//         if (uniswapV2Out > bestAmountOut) {
//             bestAmountOut = uniswapV2Out;
//             isCustomFactory = false;
//             bestProtocol = SwapProtocol.UNISWAP_V2;
//         }

//         // Execute swap using the best route
//         if (bestAmountOut == 0) {
//             revert("No valid swap path");
//         }

//         // Execute the swap via the best path
//         if (bestProtocol == SwapProtocol.AERODROME) {
//             if (isCustomFactory) {
//                 // Using a custom factory from either provided list or discovered one
//                 address useFactory = isCustomFactory && bestFactoryIndex < _aerodromeFactories.length
//                     ? _aerodromeFactories[bestFactoryIndex]
//                     : bestFactory;

//                 bool useStable = isCustomFactory && bestFactoryIndex < _stableOptions.length
//                     ? _stableOptions[bestFactoryIndex]
//                     : bestIsStable;

//                 amountOut =
//                     executeAerodromeSwapWithFactory(_tokenIn, _tokenOut, _amountIn, _recipient, useFactory, useStable);
//             } else {
//                 amountOut = _executeAerodromeSwap(_tokenIn, _tokenOut, _amountIn, _recipient);
//             }
//         } else if (bestProtocol == SwapProtocol.UNISWAP_V4) {
//             amountOut = _executeUniswapV4Swap(_tokenIn, _tokenOut, _amountIn, _recipient);
//         } else if (bestProtocol == SwapProtocol.UNISWAP_V2) {
//             amountOut = _executeUniswapV2Swap(_tokenIn, _tokenOut, _amountIn, _recipient);
//         }

//         emit OptimalSwap(_tokenIn, _tokenOut, _amountIn, amountOut, _recipient, bestProtocol);

//         return amountOut;
//     }

//     /**
//      * @notice Helper function to get all approved factory addresses from the FactoryRegistry
//      * @return factories Array of approved factory addresses
//      */
//     function _getApprovedFactories() internal view returns (address[] memory) {
//         if (FACTORY_REGISTRY == address(0)) {
//             // If no factory registry is set, return just the default factory
//             address[] memory defaultFactoryArray = new address[](1);
//             defaultFactoryArray[0] = IRouter(AERODROME_ROUTER).defaultFactory();
//             return defaultFactoryArray;
//         }

//         // Get all approved pool factories from the registry
//         return IFactoryRegistry(FACTORY_REGISTRY).poolFactories();
//     }
// }
