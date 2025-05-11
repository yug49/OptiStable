// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import {IERC20} from "./interfaces/IERC20.sol";
// import {IRouter} from "../lib/contracts/contracts/interfaces/IRouter.sol";
// import {SwapAggregator} from "./SwapAggregator.sol";

// contract VaultManager {
//     mapping(address => mapping(address => uint256)) public userBalances; // user => token => balance
//     mapping(address => uint256) public lpTokenHoldings; // lpToken => amount

//     // For LP token tracking - mapping of LP token to underlying tokens
//     mapping(address => address[2]) private _lpTokenUnderlyingTokens; // lpToken => [tokenA, tokenB]

//     address public immutable AERODROME_ROUTER;
//     address public admin;

//     // SwapAggregator address for optimal stablecoin swaps
//     address public swapAggregator;

//     event Deposit(address indexed user, address indexed token, uint256 amount);
//     event Withdrawal(address indexed user, address indexed token, uint256 amount);
//     event LiquidityAdded(address indexed lpToken, uint256 amountA, uint256 amountB, uint256 liquidity);
//     event LiquidityRemoved(address indexed lpToken, uint256 amountA, uint256 amountB);
//     event LPTokenMapped(address indexed lpToken, address indexed tokenA, address indexed tokenB);
//     event StablecoinSwapped(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

//     constructor(address _aerodromeRouter) {
//         AERODROME_ROUTER = _aerodromeRouter;
//         admin = msg.sender;
//     }

//     modifier onlyAdmin() {
//         require(msg.sender == admin, "Only admin can call this function");
//         _;
//     }

//     function deposit(IERC20 _stablecoin, uint256 _amount) external {
//         require(_amount > 0, "Deposit amount must be greater than 0");
//         require(_stablecoin.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");
//         userBalances[msg.sender][address(_stablecoin)] += _amount;
//         emit Deposit(msg.sender, address(_stablecoin), _amount);
//     }

//     function withdraw(IERC20 _stablecoin, uint256 _amount) external {
//         require(_amount > 0, "Withdrawal amount must be greater than 0");
//         require(userBalances[msg.sender][address(_stablecoin)] >= _amount, "Insufficient balance");
//         require(_stablecoin.transfer(msg.sender, _amount), "Token transfer failed");
//         userBalances[msg.sender][address(_stablecoin)] -= _amount;
//         emit Withdrawal(msg.sender, address(_stablecoin), _amount);
//     }

//     function investInAerodrome(IERC20 _stablecoinA, IERC20 _stablecoinB, uint256 _amountA, uint256 _amountB)
//         external
//         onlyAdmin
//         returns (uint256 liquidity)
//     {
//         // Approve router to spend tokens
//         require(_stablecoinA.approve(AERODROME_ROUTER, _amountA), "Approval for token A failed");
//         require(_stablecoinB.approve(AERODROME_ROUTER, _amountB), "Approval for token B failed");

//         // Call Aerodrome router to add liquidity
//         IRouter router = IRouter(AERODROME_ROUTER);

//         // Calculate minimum amounts (you might want to adjust slippage)
//         // uint256 amountAMin = (_amountA * 80) / 100; // 5% slippage
//         // uint256 amountBMin = (_amountB * 80) / 100; // 5% slippage

//         // Add liquidity to Aerodrome
//         (uint256 amountA, uint256 amountB, uint256 liquidity_) = router.addLiquidity(
//             address(_stablecoinA),
//             address(_stablecoinB),
//             true, // Assuming stable swap for stablecoins
//             _amountA,
//             _amountB,
//             0,
//             0,
//             address(this),
//             block.timestamp + 1800 // 30 minutes deadline
//         );

//         // Get LP token address
//         address lpToken = router.poolFor(
//             address(_stablecoinA),
//             address(_stablecoinB),
//             true, // stable
//             router.defaultFactory()
//         );

//         // Map LP token to its underlying tokens for future reference
//         if (_lpTokenUnderlyingTokens[lpToken][0] == address(0)) {
//             _lpTokenUnderlyingTokens[lpToken][0] = address(_stablecoinA);
//             _lpTokenUnderlyingTokens[lpToken][1] = address(_stablecoinB);
//             emit LPTokenMapped(lpToken, address(_stablecoinA), address(_stablecoinB));
//         }

//         // Track LP token holdings
//         lpTokenHoldings[lpToken] += liquidity_;

//         emit LiquidityAdded(lpToken, amountA, amountB, liquidity_);

//         return liquidity_;
//     }

//     function redeemFromAerodrome(address _lpToken, uint256 _lpAmount)
//         external
//         onlyAdmin
//         returns (uint256 amountA, uint256 amountB)
//     {
//         require(lpTokenHoldings[_lpToken] >= _lpAmount, "Insufficient LP tokens");

//         // Get the underlying tokens for this LP token
//         address tokenA = _lpTokenUnderlyingTokens[_lpToken][0];
//         address tokenB = _lpTokenUnderlyingTokens[_lpToken][1];

//         require(tokenA != address(0) && tokenB != address(0), "LP token not mapped to underlying tokens");

//         // Approve router to spend LP tokens
//         require(IERC20(_lpToken).approve(AERODROME_ROUTER, _lpAmount), "LP token approval failed");

//         // Get the Aerodrome router
//         IRouter router = IRouter(AERODROME_ROUTER);

//         // Calculate minimum amounts to receive (adjust slippage as needed)
//         (uint256 minAmountA, uint256 minAmountB) = router.quoteRemoveLiquidity(
//             tokenA,
//             tokenB,
//             true, // stable
//             router.defaultFactory(),
//             _lpAmount
//         );

//         // Apply slippage tolerance to mins (e.g., 5%)
//         minAmountA = (minAmountA * 95) / 100;
//         minAmountB = (minAmountB * 95) / 100;

//         // Remove liquidity
//         (uint256 amountA_, uint256 amountB_) = router.removeLiquidity(
//             tokenA,
//             tokenB,
//             true, // stable
//             _lpAmount,
//             minAmountA,
//             minAmountB,
//             address(this),
//             block.timestamp + 1800 // 30 minutes deadline
//         );

//         // Update LP token holdings
//         lpTokenHoldings[_lpToken] -= _lpAmount;

//         emit LiquidityRemoved(_lpToken, amountA_, amountB_);

//         return (amountA_, amountB_);
//     }

//     // Function to manually set LP token underlying tokens (backup for testing)
//     function setLPTokenUnderlyingTokens(address _lpToken, address _tokenA, address _tokenB) external onlyAdmin {
//         require(_lpToken != address(0) && _tokenA != address(0) && _tokenB != address(0), "Invalid addresses");
//         _lpTokenUnderlyingTokens[_lpToken][0] = _tokenA;
//         _lpTokenUnderlyingTokens[_lpToken][1] = _tokenB;
//         emit LPTokenMapped(_lpToken, _tokenA, _tokenB);
//     }

//     // Function to get LP token balance
//     function getLPTokenHoldings(address _lpToken) external view returns (uint256) {
//         return lpTokenHoldings[_lpToken];
//     }

//     // Admin function to update admin address
//     function setAdmin(address _newAdmin) external onlyAdmin {
//         require(_newAdmin != address(0), "New admin cannot be zero address");
//         admin = _newAdmin;
//     }

//     // Updated function to access underlying tokens by index
//     function lpTokenUnderlyingTokens(address _lpToken, uint256 _index) public view returns (address) {
//         require(_index < 2, "Index out of bounds");
//         return _lpTokenUnderlyingTokens[_lpToken][_index];
//     }

//     // Function to invest in Aerodrome with custom factory selection
//     function investInAerodromeWithFactory(
//         IERC20 _stablecoinA,
//         IERC20 _stablecoinB,
//         uint256 _amountA,
//         uint256 _amountB,
//         address _factory,
//         bool _stable
//     ) external onlyAdmin returns (uint256 liquidity) {
//         // Approve router to spend tokens
//         require(_stablecoinA.approve(AERODROME_ROUTER, _amountA), "Approval for token A failed");
//         require(_stablecoinB.approve(AERODROME_ROUTER, _amountB), "Approval for token B failed");

//         // Call Aerodrome router to add liquidity
//         IRouter router = IRouter(AERODROME_ROUTER);

//         // Add liquidity to Aerodrome with specified factory
//         (uint256 amountA, uint256 amountB, uint256 liquidity_) = router.addLiquidity(
//             address(_stablecoinA),
//             address(_stablecoinB),
//             _stable, // Use stability parameter passed by user
//             _amountA,
//             _amountB,
//             0,
//             0,
//             address(this),
//             block.timestamp + 1800 // 30 minutes deadline
//         );

//         // Get LP token address with specified factory
//         address lpToken = router.poolFor(address(_stablecoinA), address(_stablecoinB), _stable, _factory);

//         // Map LP token to its underlying tokens for future reference
//         if (_lpTokenUnderlyingTokens[lpToken][0] == address(0)) {
//             _lpTokenUnderlyingTokens[lpToken][0] = address(_stablecoinA);
//             _lpTokenUnderlyingTokens[lpToken][1] = address(_stablecoinB);
//             emit LPTokenMapped(lpToken, address(_stablecoinA), address(_stablecoinB));
//         }

//         // Track LP token holdings
//         lpTokenHoldings[lpToken] += liquidity_;

//         emit LiquidityAdded(lpToken, amountA, amountB, liquidity_);

//         return liquidity_;
//     }

//     // Function to redeem from Aerodrome with custom factory selection
//     function redeemFromAerodromeWithFactory(address _lpToken, uint256 _lpAmount, address _factory, bool _stable)
//         external
//         onlyAdmin
//         returns (uint256 amountA, uint256 amountB)
//     {
//         require(lpTokenHoldings[_lpToken] >= _lpAmount, "Insufficient LP tokens");

//         // Get the underlying tokens for this LP token
//         address tokenA = _lpTokenUnderlyingTokens[_lpToken][0];
//         address tokenB = _lpTokenUnderlyingTokens[_lpToken][1];

//         require(tokenA != address(0) && tokenB != address(0), "LP token not mapped to underlying tokens");

//         // Approve router to spend LP tokens
//         require(IERC20(_lpToken).approve(AERODROME_ROUTER, _lpAmount), "LP token approval failed");

//         // Get the Aerodrome router
//         IRouter router = IRouter(AERODROME_ROUTER);

//         // Calculate minimum amounts to receive (adjust slippage as needed)
//         (uint256 minAmountA, uint256 minAmountB) = router.quoteRemoveLiquidity(
//             tokenA,
//             tokenB,
//             _stable, // Use stability parameter passed by user
//             _factory, // Use factory address passed by user
//             _lpAmount
//         );

//         // Apply slippage tolerance to mins (e.g., 5%)
//         minAmountA = (minAmountA * 95) / 100;
//         minAmountB = (minAmountB * 95) / 100;

//         // Remove liquidity
//         (uint256 amountA_, uint256 amountB_) = router.removeLiquidity(
//             tokenA,
//             tokenB,
//             _stable, // Use stability parameter passed by user
//             _lpAmount,
//             minAmountA,
//             minAmountB,
//             address(this),
//             block.timestamp + 1800 // 30 minutes deadline
//         );

//         // Update LP token holdings
//         lpTokenHoldings[_lpToken] -= _lpAmount;

//         emit LiquidityRemoved(_lpToken, amountA_, amountB_);

//         return (amountA_, amountB_);
//     }

//     // Function to set SwapAggregator address
//     function setSwapAggregator(address _swapAggregator) external onlyAdmin {
//         require(_swapAggregator != address(0), "SwapAggregator cannot be zero address");
//         swapAggregator = _swapAggregator;
//     }

//     // Function to swap tokens using SwapAggregator with custom factory selection
//     function swapWithCustomFactories(
//         IERC20 _tokenIn,
//         IERC20 _tokenOut,
//         uint256 _amountIn,
//         address _recipient,
//         address[] calldata _aerodromeFactories,
//         bool[] calldata _stableOptions
//     ) external onlyAdmin returns (uint256 amountOut) {
//         require(address(swapAggregator) != address(0), "SwapAggregator not set");
//         require(_amountIn > 0, "Amount must be greater than 0");
//         require(_recipient != address(0), "Invalid recipient");

//         // Approve SwapAggregator to spend tokens
//         require(_tokenIn.approve(swapAggregator, _amountIn), "Approval for SwapAggregator failed");

//         // Execute swap through SwapAggregator with custom factory options
//         amountOut = SwapAggregator(swapAggregator).executeOptimalSwapWithFactories(
//             address(_tokenIn), address(_tokenOut), _amountIn, _recipient, _aerodromeFactories, _stableOptions
//         );

//         emit StablecoinSwapped(address(_tokenIn), address(_tokenOut), _amountIn, amountOut);

//         return amountOut;
//     }

//     // Function to query best swap route across multiple factories
//     function getBestSwapRoute(
//         address _tokenIn,
//         address _tokenOut,
//         uint256 _amountIn,
//         address[] calldata _aerodromeFactories,
//         bool[] calldata _stableOptions
//     ) external view returns (uint256 bestAmountOut, uint256 bestRouteIndex, bool isCustomFactory) {
//         require(address(swapAggregator) != address(0), "SwapAggregator not set");
//         require(_aerodromeFactories.length == _stableOptions.length, "Array length mismatch");

//         SwapAggregator aggregator = SwapAggregator(swapAggregator);

//         // Get quotes from standard protocols
//         uint256 aerodromeOut = aggregator.getAmountOutAerodrome(_tokenIn, _tokenOut, _amountIn);
//         uint256 uniswapV2Out = aggregator.getAmountOutUniswapV2(_tokenIn, _tokenOut, _amountIn);

//         // Find the best quote among custom Aerodrome factories
//         uint256 bestCustomAerodromeOut = 0;
//         uint256 bestFactoryIndex = 0;

//         for (uint256 i = 0; i < _aerodromeFactories.length; i++) {
//             uint256 customOut = aggregator.getAmountOutAerodromeWithFactory(
//                 _tokenIn, _tokenOut, _amountIn, _aerodromeFactories[i], _stableOptions[i]
//             );

//             if (customOut > bestCustomAerodromeOut) {
//                 bestCustomAerodromeOut = customOut;
//                 bestFactoryIndex = i;
//             }
//         }

//         // Determine the best route
//         if (
//             bestCustomAerodromeOut > 0 && bestCustomAerodromeOut >= aerodromeOut
//                 && bestCustomAerodromeOut >= uniswapV2Out
//         ) {
//             return (bestCustomAerodromeOut, bestFactoryIndex, true);
//         } else if (aerodromeOut >= uniswapV2Out) {
//             return (aerodromeOut, 0, false);
//         } else {
//             return (uniswapV2Out, 0, false);
//         }
//     }
// }
