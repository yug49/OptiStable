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
import {Commands} from "./libraries/Commands.sol";
import {IQuoterV2} from "../lib/v3-periphery/contracts/interfaces/IQuoterV2.sol";
import {IUniversalRouter} from "./interfaces/IUniversalRouter.sol";
import {PoolKey} from "../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import {IHooks} from "../lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

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

    address public immutable i_aerodomeRouter;
    address public immutable i_uniswapV2Router;
    address public immutable i_uniswapV4Router;
    address public immutable i_uniswapV4Quoter;
    address public immutable i_factoryRegistry;
    address public immutable i_aerodromeMultiRouter;
    address public immutable i_universalRouter;
    address public immutable i_uniswapV3Quoter;
    address public owner;
    uint256 private constant DEADLINE = 20 minutes;
    uint24 private constant DEFAULT_UNISWAP_FEE = 3000; //0.3 %
    int24 constant VOLATILE_BITMASK = 4194304;
    int24 constant STABLE_BITMASK = 2097152;
    

    enum SwapProtocol {
        AERODOME_V2,
        AERODOME_V3,
        UNISWAP_X,
        UNISWAP_V2,
        UNISWAP_V3,
        UNISWAP_V4
    }

    event OptimalSwap(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountOut,
        address indexed recipient,
        SwapProtocol protocol
    );

    event UniswapV4SwapExecuted(
        uint256 amountOut,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn
    );

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
        address _uniswapV2Router,
        address _uniswapV3Quoter,
        address _uniswapV4Router,
        address _uniswapV4Quoter,
        address _factoryRegistry,
        address _aerodromeMultiRouter,
        address _universalRouter
    ) {
        i_aerodomeRouter = _aerodromeRouter;
        i_uniswapV2Router = _uniswapV2Router;
        i_uniswapV4Router = _uniswapV4Router;
        i_uniswapV4Quoter = _uniswapV4Quoter;
        i_factoryRegistry = _factoryRegistry;
        i_aerodromeMultiRouter = _aerodromeMultiRouter;
        i_universalRouter = _universalRouter;
        i_uniswapV3Quoter = _uniswapV3Quoter;

        // Set the owner of the contract to the deployer
        owner = msg.sender;
    }

    /**
     * @dev Modifier to restrict access to the owner
     */
    modifier onOwner() {
        if (msg.sender != owner) {
            revert SwapAggregator__NotOwner();
        }
        _;
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
        returns (uint256 amountOut, SwapProtocol protocol)
    {
        if (_amountIn == 0) revert SwapAggregator__InvalidAmount();
        if (_recipient == address(0)) revert SwapAggregator__InvalidRecipient();
        if (_tokenIn == address(0) || _tokenOut == address(0)) revert SwapAggregator__InvalidTokenAddresses();
        if(_tokenIn == _tokenOut) revert SwapAggregator__InvalidTokenAddresses();

        int24[] memory aerodromeTickSpacings = getAerodromeTickSpacings();

        for (uint256 i = 0; i < aerodromeTickSpacings.length; i++) {
            int24 tickSpacing = aerodromeTickSpacings[i];

            if (tickSpacing & VOLATILE_BITMASK != 0) {
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
                    protocol = SwapProtocol.AERODOME_V2;
                }
            } else if (tickSpacing & STABLE_BITMASK != 0) {
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
                    protocol = SwapProtocol.AERODOME_V2;
                }
            } else {
                /// the outputs of prior swaps become the inputs to subsequent ones
                (uint256 amountHere,,,) = IMixedRouteQuoterV1(i_aerodromeMultiRouter).quoteExactInputSingleV3(
                    IMixedRouteQuoterV1.QuoteExactInputSingleV3Params({
                        tokenIn: _tokenIn,
                        tokenOut: _tokenOut,
                        tickSpacing: tickSpacing,
                        amountIn: _amountIn,
                        sqrtPriceLimitX96: 0
                    })
                );
                if (amountHere > amountOut) {
                    amountOut = amountHere;
                    protocol = SwapProtocol.AERODOME_V3;
                }
            }
            i++;
        }
    }

    /**
     * @dev subgraph query
        {
          eurc_usdc: pools(
            where: {
              token0: "0x60a3e35cc302bfa44cb288bc5a4f316fdb1adb42",
              token1: "0x833589fcd6edb6e08f4c7c32d4f71b54bda02913"
            }
          ) {
            id
            feeTier
            tickSpacing
            hooks
          }
        }
     */
    /**
     * @dev Gets the optimal swap amount out from uniswap v4 by analazing all the pools of a given token pair
     * @param tokenIn address of token to swap from
     * @param tokenOut address of token to swap to
     * @param amountIn amount of token to swap
     * @param poolFees array of pool fees of all available pools of a given token pair in uniswap v3
     * @return amountOut amount of token received after the swap
     * @return protocol protocol used for the swap
     */
    function getAmountOutUniswapV4(address tokenIn, address tokenOut, uint256 amountIn, uint24[] memory poolFees, int24[] memory tickSpacings, address[] memory hooks)
        public
        returns (uint256 amountOut, SwapProtocol protocol){
        if (amountIn == 0) revert SwapAggregator__InvalidAmount();
        if (poolFees.length == 0) revert SwapAggregator__InvalidPoolFees();
        if (tokenIn == address(0) || tokenOut == address(0)) revert SwapAggregator__InvalidTokenAddresses();
        if (tokenIn == tokenOut) revert SwapAggregator__InvalidTokenAddresses();

        for(uint i = 0 ; i < poolFees.length; i++) {
            uint24 fee = poolFees[i];
            int24 tickSpacing = tickSpacings[i];
            address hook = hooks[i];
            (uint256 amountHere, ) = getAmountOutUniswapV4FromSpecificPool(
                tokenIn,
                tokenOut,
                amountIn,
                fee,
                tickSpacing,
                hook
            );
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
     * @return amountOut amount of token received after the swap
     * @return protocol protocol used for the swap
     */
    function getAmountOutUniswapV4FromSpecificPool(address tokenIn, address tokenOut, uint256 amountIn, uint24 fee, int24 tickSpacing, address hook)
        public
        returns (uint256 amountOut, SwapProtocol protocol)
    {   
        if (amountIn == 0) revert SwapAggregator__InvalidAmount();
        if (fee == 0) revert SwapAggregator__InvalidPoolFees();
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
        ) returns (
            uint256 result,
            uint256 /* gasEstimate */
        ) {
            amountOut = result;
            protocol = SwapProtocol.UNISWAP_V4;
        } catch {
            // If the quote fails (e.g., pool doesn't exist), return 0
            amountOut = 0;
            protocol = SwapProtocol.UNISWAP_V4;
        }
    }

    // /**
    //  * @dev Gets the optimal swap amount out from uniswap v4 from a specific pool identified by the fee
    //  * @param tokenIn address of token to swap from
    //  * @param tokenOut address of token to swap to
    //  * @param amountIn amount of token to swap
    //  * @param fee fee for the swap
    //  * @return amountOut amount of token received after the swap
    //  * @return protocol protocol used for the swap
    //  */
    // function swapUniswapV4FromSpecificPool(address tokenIn, address tokenOut, uint256 amountIn, uint24 fee, int24 tickSpacing, address hook)
    //     public
    //     returns (uint256 amountOut, SwapProtocol protocol)
    // {   
    //     if (amountIn == 0) revert SwapAggregator__InvalidAmount();
    //     if (fee == 0) revert SwapAggregator__InvalidPoolFees();
    //     if (tokenIn == address(0) || tokenOut == address(0)) revert SwapAggregator__InvalidTokenAddresses();
    //     if (tokenIn == tokenOut) revert SwapAggregator__InvalidTokenAddresses();

    //     Currency currency0 = tokenIn < tokenOut ? Currency.wrap(tokenIn) : Currency.wrap(tokenOut);
    //     Currency currency1 = tokenIn < tokenOut ? Currency.wrap(tokenOut) : Currency.wrap(tokenIn);
    //     IHooks hooks = IHooks(hook);

    //     try IV4Router(i_uniswapV4Router).quoteExactInputSingle(
    //             IV4Router.ExactInputSingleParams({
    //                 poolKey: PoolKey({
    //                     currency0: currency0,
    //                     currency1: currency1,
    //                     fee: fee,
    //                     tickSpacing: tickSpacing,
    //                     hooks: hooks
    //                 }),
    //                 zeroForOne: tokenIn < tokenOut ? true : false,
    //                 exactAmount: uint128(amountIn),
    //                 hookData: ""
    //             })
    //     ) returns (
    //         uint256 result,
    //         uint256 /* gasEstimate */
    //     ) {
    //         amountOut = result;
    //         protocol = SwapProtocol.UNISWAP_V4;
    //     } catch {
    //         // If the quote fails (e.g., pool doesn't exist), return 0
    //         amountOut = 0;
    //         protocol = SwapProtocol.UNISWAP_V4;
    //     }

    //     emit UniswapV4SwapExecuted(amountOut, tokenIn, tokenOut, amountIn);
    // }

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
        returns (uint256 amountOut, SwapProtocol protocol){
        if (amountIn == 0) revert SwapAggregator__InvalidAmount();
        if (poolFees.length == 0) revert SwapAggregator__InvalidPoolFees();
        if (tokenIn == address(0) || tokenOut == address(0)) revert SwapAggregator__InvalidTokenAddresses();
        if (tokenIn == tokenOut) revert SwapAggregator__InvalidTokenAddresses();


        for(uint i = 0 ; i < poolFees.length; i++) {
            uint24 fee = poolFees[i];
            (uint256 amountHere, ) = getAmountOutUniswapV3FromSpecificPool(
                tokenIn,
                tokenOut,
                amountIn,
                fee
            );
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
            uint160 /* sqrtPriceX96After */,
            uint32  /* initializedTicksCrossed */,
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

    // /**
    //  * @notice Execute a swap using Uniswap Universal Router
    //  * @param _tokenIn Address of input token
    //  * @param _tokenOut Address of output token
    //  * @param _amountIn Amount of input token
    //  * @param _amountOutMin Minimum amount of output token to receive
    //  * @param _recipient Address to receive output tokens
    //  * @param _version Which Uniswap version to use (2, 3, or 4)
    //  * @return amountOut Amount of output tokens received
    //  */
    // function swapExactInputSingleUniversal(
    //     address _tokenIn,
    //     address _tokenOut,
    //     uint256 _amountIn,
    //     uint256 _amountOutMin,
    //     address _recipient,
    //     uint8 _version,
    //     uint24 _poolFee,
    //     int24 _tickSpacing,
    //     address _hook
    // ) external returns (uint256 amountOut) {
    //     if (_amountIn == 0) revert SwapAggregator__InvalidAmount();
    //     if (_recipient == address(0)) revert SwapAggregator__InvalidRecipient();
        
    //     // Transfer tokens from sender to this contract
    //     IERC20(_tokenIn).transferFrom(_recipient, address(this), _amountIn);
        
    //     // Approve Universal Router to spend our tokens
    //     IERC20(_tokenIn).approve(i_universalRouter, _amountIn);
        
    //     // Prepare the command and inputs based on Uniswap version
    //     bytes memory commands;
    //     bytes[] memory inputs = new bytes[](2);
        
    //     // First command: Permit2 transfer from this contract to Universal Router
    //     commands = bytes.concat(Commands.PERMIT2_TRANSFER_FROM);
        
    //     // Second command: Execute the swap based on version
    //     if (_version == 2) {
    //         commands = bytes.concat(commands, Commands.V2_SWAP_EXACT_IN);
            
    //         // V2 swap parameters (recipient, amountOutMin, path)
    //         address[] memory path = new address[](2);
    //         path[0] = _tokenIn;
    //         path[1] = _tokenOut;
            
    //         inputs[1] = abi.encode(
    //             _recipient,              // recipient
    //             _amountIn,               // amountIn
    //             _amountOutMin,           // amountOutMin
    //             path,                    // path
    //             false                    // payerIsUser (false because our contract pays)
    //         );
    //     } else if (_version == 3) {
    //         commands = bytes.concat(commands, Commands.V3_SWAP_EXACT_IN);
            
    //         // V3 swap parameters
    //         bytes memory path = abi.encodePacked(
    //             _tokenIn,                // tokenIn
    //             _poolFee,            // fee (0.3%)
    //             _tokenOut                // tokenOut
    //         );
            
    //         inputs[1] = abi.encode(
    //             _recipient,              // recipient
    //             _amountIn,               // amountIn
    //             _amountOutMin,           // amountOutMin
    //             path,                    // path
    //             false                    // payerIsUser
    //         );
    //     } else if (_version == 4) {
    //         commands = bytes.concat(commands, Commands.V4_SWAP_EXACT_IN);
            
    //         // V4 swap parameters
    //         inputs[1] = abi.encode(
    //             _recipient,              // recipient
    //             _amountIn,               // amountIn
    //             _amountOutMin,           // amountOutMin
    //             _tokenIn,                // tokenIn
    //             _tokenOut,               // tokenOut
    //             uint24(3000),            // poolFee (0.3%)
    //             false                    // payerIsUser
    //         );
    //     } else {
    //         revert("Unsupported Uniswap version");
    //     }
        
    //     // Permit2 transfer parameters
    //     inputs[0] = abi.encode(
    //         address(this),              // from
    //         _tokenIn,                   // token
    //         _amountIn                   // amount
    //     );
        
    //     // Execute the commands with a 20-minute deadline
    //     uint256 deadline = block.timestamp + DEADLINE;
    //     IUniversalRouter(i_universalRouter).execute(commands, inputs, deadline);
        
    //     // Return actual amount received (would need to calculate this)
    //     // For simplicity, we'll assume the swap succeeded with at least _amountOutMin
    //     return _amountOutMin;
    // }
    
    // /**
    //  * @notice Execute a UniswapX order using Universal Router
    //  * @param commands The encoded commands for Universal Router
    //  * @param inputs The inputs for each command
    //  * @dev This is a more flexible way to interact with Universal Router for complex swaps
    //  */
    // function executeWithUniversalRouter(
    //     bytes calldata commands,
    //     bytes[] calldata inputs
    // ) external payable {
    //     uint256 deadline = block.timestamp + DEADLINE;
    //     IUniversalRouter(i_universalRouter).execute{value: msg.value}(commands, inputs, deadline);
    // }

    
}
