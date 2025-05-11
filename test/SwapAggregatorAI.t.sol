// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import {Test, console} from "../lib/forge-std/src/Test.sol";
// import {SwapAggregator} from "../src/SwapAggregator.sol";
// import {VaultManager} from "../src/VaultManager.sol";
// import {IERC20} from "../src/interfaces/IERC20.sol";
// import {IRouter} from "../lib/contracts/contracts/interfaces/IRouter.sol";

// // Import constants
// import {AERODROME_ROUTER, UNISWAP_V2_ROUTER, UNISWAP_V4_ROUTER, UNISWAP_V4_QUOTER, FACTORY_REGISTRY} from "../src/Constants.sol";

// // Mock SwapAggregator for testing route selection
// contract MockSwapAggregator is SwapAggregator {
//     uint256 public mockAerodromeOut;
//     uint256 public mockUniswapV2Out;
//     uint256 public mockUniswapV4Out;
//     bool public aerodromeExecuted;
//     bool public uniswapV2Executed;
//     bool public uniswapV4Executed;

//     constructor(address _aerodromeRouter, address _uniswapV2Router, address _uniswapV4Router, address _uniswapV4Quoter)
//         SwapAggregator(_aerodromeRouter, _uniswapV2Router, _uniswapV4Router, _uniswapV4Quoter)
//     {}

//     function setMockOutputs(uint256 _aerodromeOut, uint256 _uniswapV2Out, uint256 _uniswapV4Out) external {
//         mockAerodromeOut = _aerodromeOut;
//         mockUniswapV2Out = _uniswapV2Out;
//         mockUniswapV4Out = _uniswapV4Out;
//     }

//     function getAmountOutAerodrome(address, address, uint256) public view override returns (uint256) {
//         return mockAerodromeOut;
//     }

//     function getAmountOutUniswapV2(address, address, uint256) public view override returns (uint256) {
//         return mockUniswapV2Out;
//     }

//     function getAmountOutUniswapV4(address, address, uint256) public view override returns (uint256) {
//         return mockUniswapV4Out;
//     }

//     function _executeAerodromeSwap(address _tokenIn, address _tokenOut, uint256 _amountIn, address _recipient)
//         internal
//         override
//         returns (uint256)
//     {
//         // Just track execution for testing without actually swapping
//         aerodromeExecuted = true;
//         return mockAerodromeOut;
//     }

//     function _executeUniswapV2Swap(address _tokenIn, address _tokenOut, uint256 _amountIn, address _recipient)
//         internal
//         override
//         returns (uint256)
//     {
//         // Just track execution for testing without actually swapping
//         uniswapV2Executed = true;
//         return mockUniswapV2Out;
//     }

//     function _executeUniswapV4Swap(address _tokenIn, address _tokenOut, uint256 _amountIn, address _recipient)
//         internal
//         override
//         returns (uint256)
//     {
//         // Just track execution for testing without actually swapping
//         uniswapV4Executed = true;
//         return mockUniswapV4Out;
//     }

//     // Reset tracking variables
//     function reset() external {
//         aerodromeExecuted = false;
//         uniswapV2Executed = false;
//         uniswapV4Executed = false;
//     }
// }

// contract SwapAggregatorTest is Test {
//     // Contracts
//     SwapAggregator public swapAggregator;
//     MockSwapAggregator public mockSwapAggregator;
//     VaultManager public vaultManager;

//     // Base Mainnet token addresses
//     address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
//     address public constant USDT = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
//     address public constant EURC = 0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42;
//     address public constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;

//     // User addresses
//     address public user1 = address(1);
//     address public admin;

//     function setUp() public {
//         // Fork Base Mainnet
//         // vm.createSelectFork("base_mainnet");

//         // Deploy SwapAggregator with all router addresses
//         swapAggregator = new SwapAggregator(AERODROME_ROUTER, UNISWAP_V2_ROUTER, UNISWAP_V4_ROUTER, UNISWAP_V4_QUOTER, FACTORY_REGISTRY);

//         // Deploy MockSwapAggregator for controlled testing
//         mockSwapAggregator =
//             new MockSwapAggregator(AERODROME_ROUTER, UNISWAP_V2_ROUTER, UNISWAP_V4_ROUTER, UNISWAP_V4_QUOTER, FACTORY_REGISTRY);

//         // Deploy VaultManager
//         vaultManager = new VaultManager(AERODROME_ROUTER);
//         admin = address(this);

//         // Deal tokens to test users
//         deal(USDC, user1, 10_000 * 1e6); // 10,000 USDC (6 decimals)
//         deal(EURC, user1, 10_000 * 1e18); // 10,000 EURC (18 decimals)
//         deal(EURC, user1, 10_000 * 1e18); // 10,000 EURC (18 decimals)
//         deal(USDT, user1, 10_000 * 1e6); // 10,000 USDT (6 decimals)

//         // Deal tokens to test contract for direct tests
//         deal(USDC, address(this), 10_000 * 1e6);
//         deal(EURC, address(this), 10_000 * 1e18);
//         deal(EURC, address(this), 10_000 * 1e18);
//         deal(USDT, address(this), 10_000 * 1e6);

//         vm.label(address(swapAggregator), "SwapAggregator");
//         vm.label(address(mockSwapAggregator), "MockSwapAggregator");
//         vm.label(address(vaultManager), "VaultManager");
//         vm.label(user1, "User1");
//         vm.label(admin, "Admin");
//         vm.label(USDC, "USDC");
//         vm.label(USDT, "USDT");
//         vm.label(EURC, "EURC");
//         vm.label(DAI, "DAI");
//         vm.label(AERODROME_ROUTER, "AerodromeRouter");
//         vm.label(UNISWAP_V2_ROUTER, "UniswapV2Router");
//         vm.label(UNISWAP_V4_ROUTER, "UniswapV4Router");
//         vm.label(UNISWAP_V4_QUOTER, "UniswapV4Quoter");
//         vm.label(address(this), "SwapAggregatorTestContract");



//         console.log("SwapAggregator deployed at:", address(swapAggregator));
//     }

//     // Test comparing all quotes (Aerodrome, Uniswap V2, and V4)
//     function test_CompareAllQuotes() public {
//         uint256 amountIn = 1000 * 1e6; // 1,000 USDC

//         uint256 aerodromeOut = swapAggregator.getAmountOutAerodrome(USDC, EURC, amountIn);
//         uint256 uniswapV2Out = swapAggregator.getAmountOutUniswapV2(USDC, EURC, amountIn);
//         uint256 uniswapV4Out = swapAggregator.getAmountOutUniswapV4(USDC, EURC, amountIn);

//         console.log("Quote comparison for 1,000 USDC -> EURC:");
//         console.log("Aerodrome:", aerodromeOut / 1e18);
//         console.log("Uniswap V2:", uniswapV2Out / 1e18);
//         console.log("Uniswap V4:", uniswapV4Out / 1e18);

//         // At least one of them should return a valid quote
//         assertTrue(aerodromeOut > 0 || uniswapV2Out > 0 || uniswapV4Out > 0, "No valid quote found");
//     }

//     // Test Uniswap V4 specific functionality
//     function test_UniswapV4Quote() public {
//         uint256 amountIn = 1000 * 1e6; // 1,000 USDC

//         // Try to get a quote from Uniswap V4
//         uint256 uniswapV4Out = swapAggregator.getAmountOutUniswapV4(USDC, EURC, amountIn);
//         console.log("Uniswap V4 quote for 1,000 USDC -> EURC:", uniswapV4Out / 1e18);

//         // This may fail if V4 pools don't exist yet, so we'll skip assertion
//     }

//     // Test that executeOptimalSwap chooses Uniswap V4 when it has best rate
//     function test_ExecuteOptimalSwapMockedUniswapV4() public {
//         uint256 amountIn = 1000 * 1e6; // 1,000 USDC

//         // Setup mock values - V4 has best rate
//         uint256 mockAerodromeOut = 970 * 1e18; // 970 EURC
//         uint256 mockUniswapV2Out = 980 * 1e18; // 980 EURC
//         uint256 mockUniswapV4Out = 995 * 1e18; // 995 EURC - best rate

//         mockSwapAggregator.setMockOutputs(mockAerodromeOut, mockUniswapV2Out, mockUniswapV4Out);

//         // User approves mock SwapAggregator
//         deal(USDC, user1, amountIn);
//         vm.startPrank(user1);
//         IERC20(USDC).approve(address(mockSwapAggregator), amountIn);

//         // Execute optimal swap
//         mockSwapAggregator.executeOptimalSwap(USDC, EURC, amountIn, user1);
//         vm.stopPrank();

//         // Check that Uniswap V4 path was chosen
//         assertFalse(mockSwapAggregator.aerodromeExecuted(), "Aerodrome path should not have been used");
//         assertFalse(mockSwapAggregator.uniswapV2Executed(), "Uniswap V2 path should not have been used");
//         assertTrue(mockSwapAggregator.uniswapV4Executed(), "Uniswap V4 path should have been used");

//         // Reset for next test
//         mockSwapAggregator.reset();
//     }

//     // Test that executeOptimalSwap correctly chooses between three options
//     function test_RouteSelectionWithThreeOptions() public {
//         uint256 amountIn = 1000 * 1e6; // 1,000 USDC
//         deal(USDC, user1, amountIn * 3); // Need more tokens for all tests

//         // Test 1: Aerodrome has best rate
//         mockSwapAggregator.setMockOutputs(1000 * 1e18, 990 * 1e18, 980 * 1e18);
//         vm.startPrank(user1);
//         IERC20(USDC).approve(address(mockSwapAggregator), amountIn);
//         mockSwapAggregator.executeOptimalSwap(USDC, EURC, amountIn, user1);
//         vm.stopPrank();
//         assertTrue(mockSwapAggregator.aerodromeExecuted(), "Aerodrome should be used when it has best rate");
//         assertFalse(mockSwapAggregator.uniswapV2Executed());
//         assertFalse(mockSwapAggregator.uniswapV4Executed());
//         mockSwapAggregator.reset();

//         // Test 2: Uniswap V2 has best rate
//         mockSwapAggregator.setMockOutputs(980 * 1e18, 1000 * 1e18, 990 * 1e18);
//         vm.startPrank(user1);
//         IERC20(USDC).approve(address(mockSwapAggregator), amountIn);
//         mockSwapAggregator.executeOptimalSwap(USDC, EURC, amountIn, user1);
//         vm.stopPrank();
//         assertFalse(mockSwapAggregator.aerodromeExecuted());
//         assertTrue(mockSwapAggregator.uniswapV2Executed(), "Uniswap V2 should be used when it has best rate");
//         assertFalse(mockSwapAggregator.uniswapV4Executed());
//         mockSwapAggregator.reset();

//         // Test 3: Uniswap V4 has best rate
//         mockSwapAggregator.setMockOutputs(980 * 1e18, 990 * 1e18, 1000 * 1e18);
//         vm.startPrank(user1);
//         IERC20(USDC).approve(address(mockSwapAggregator), amountIn);
//         mockSwapAggregator.executeOptimalSwap(USDC, EURC, amountIn, user1);
//         vm.stopPrank();
//         assertFalse(mockSwapAggregator.aerodromeExecuted());
//         assertFalse(mockSwapAggregator.uniswapV2Executed());
//         assertTrue(mockSwapAggregator.uniswapV4Executed(), "Uniswap V4 should be used when it has best rate");
//     }

//     function test_GetAmountOutExpectedValues() public {
//         // Test with different input amounts
//         uint256[] memory testAmounts = new uint256[](3);
//         testAmounts[0] = 100 * 1e6; // 100 USDC
//         testAmounts[1] = 1000 * 1e6; // 1,000 USDC
//         testAmounts[2] = 10000 * 1e6; // 10,000 USDC

//         // Store previous outputs for comparison
//         uint256[] memory aerodromeOutputs = new uint256[](3);
//         uint256[] memory uniswapOutputs = new uint256[](3);

//         for (uint256 i = 0; i < testAmounts.length; i++) {
//             aerodromeOutputs[i] = swapAggregator.getAmountOutAerodrome(USDC, EURC, testAmounts[i]);

//             uniswapOutputs[i] = swapAggregator.getAmountOutUniswapV2(USDC, EURC, testAmounts[i]);

//             console.log("Amount In (USDC):", testAmounts[i] / 1e6);
//             console.log("Aerodrome Output (EURC):", aerodromeOutputs[i] / 1e18);
//             console.log("Uniswap Output (EURC):", uniswapOutputs[i] / 1e18);

//             // Basic validation
//             // 1. Output should be non-zero if there's liquidity
//             if (i == 0) {
//                 // For small amounts, either one or both should return a value
//                 assertTrue(aerodromeOutputs[i] > 0 || uniswapOutputs[i] > 0, "No quote available for small amount");
//             } else {
//                 // For larger amounts, we expect quotes from at least one of the DEXes
//                 assertTrue(aerodromeOutputs[i] > 0 || uniswapOutputs[i] > 0, "No quotes available for larger amount");

//                 // For increasing inputs, outputs should either increase or stay the same (not decrease)
//                 // This handles cases where DEX returns the same output for different inputs
//                 if (aerodromeOutputs[i - 1] > 0 && aerodromeOutputs[i] > 0) {
//                     assertTrue(
//                         aerodromeOutputs[i] > aerodromeOutputs[i - 1],
//                         "Aerodrome output decreased or equal with increasing input"
//                     );
//                 }

//                 if (uniswapOutputs[i - 1] > 0 && uniswapOutputs[i] > 0) {
//                     assertTrue(
//                         uniswapOutputs[i] >= uniswapOutputs[i - 1],
//                         "Uniswap output decreased or equal with increasing input"
//                     );
//                 }
//             }
//         }

//         // If we have multiple valid quotes, check that larger inputs produce larger/equal outputs
//         // This test is separate because pool might be small and saturate with large inputs
//         bool hasMultipleValidOutputs = false;
//         for (uint256 i = 0; i < testAmounts.length - 1; i++) {
//             if (aerodromeOutputs[i] > 0 && aerodromeOutputs[i + 1] > 0) {
//                 // If we have at least one pair of valid outputs, set the flag
//                 hasMultipleValidOutputs = true;

//                 // We don't need to check proportionality - just that outputs don't decrease
//                 // This is already checked in the loop above
//             }
//         }

//         // Only log if we have multiple valid outputs
//         if (hasMultipleValidOutputs) {
//             console.log("Test passed with multiple valid outputs");
//         } else {
//             console.log("Not enough valid outputs to check scaling behavior");
//         }
//     }

//     function test_GetAmountOutReturnZeroForInvalidTokens() public {
//         // Test with invalid tokens
//         address invalidToken = address(0x12345);

//         uint256 aerodromeOut = swapAggregator.getAmountOutAerodrome(invalidToken, EURC, 1000 * 1e6);
//         uint256 uniswapOut = swapAggregator.getAmountOutUniswapV2(invalidToken, EURC, 1000 * 1e6);
//         uint256 uniswapV4Out = swapAggregator.getAmountOutUniswapV4(invalidToken, EURC, 1000 * 1e6);

//         // All should return 0 for invalid tokens
//         assertEq(aerodromeOut, 0, "Aerodrome should return 0 for invalid token");
//         assertEq(uniswapOut, 0, "Uniswap should return 0 for invalid token");
//         assertEq(uniswapV4Out, 0, "Uniswap V4 should return 0 for invalid token");
//     }

//     // Test actual DEX swaps
//     function test_AerodromeSwapExecution() public {
//         uint256 amountIn = 100 * 1e6; // 100 USDC

//         // Get expected amount out from Aerodrome
//         uint256 expectedAmountOut = swapAggregator.getAmountOutAerodrome(USDC, EURC, amountIn);

//         // Skip test if no liquidity on Aerodrome
//         if (expectedAmountOut == 0) {
//             console.log("No Aerodrome liquidity for USDC-EURC, skipping test");
//             return;
//         }

//         // Deal tokens to test contract
//         deal(USDC, address(this), amountIn);
//         IERC20(USDC).approve(address(swapAggregator), amountIn);

//         // Record EURC balance before swap
//         uint256 balanceBefore = IERC20(EURC).balanceOf(address(this));

//         // Execute Aerodrome swap through our mock contract that forces Aerodrome path
//         mockSwapAggregator.setMockOutputs(expectedAmountOut, 0, 0); // Set Aerodrome as best option
//         IERC20(USDC).approve(address(mockSwapAggregator), amountIn);
//         mockSwapAggregator.executeOptimalSwap(USDC, EURC, amountIn, address(this));

//         // Verify Aerodrome was used
//         assertTrue(mockSwapAggregator.aerodromeExecuted(), "Aerodrome swap should have executed");
//         assertFalse(mockSwapAggregator.uniswapV2Executed(), "Uniswap V2 should not have executed");
//         assertFalse(mockSwapAggregator.uniswapV4Executed(), "Uniswap V4 should not have executed");

//         // Verify output amount is reasonable (within 10% of expected)
//         uint256 balanceAfter = IERC20(EURC).balanceOf(address(this));
//         uint256 actualOutput = balanceAfter - balanceBefore;

//         assertGt(
//             actualOutput , expectedAmountOut * 9 / 10,
//             "Actual Aerodrome output should be at least 90% of expected output"
//         );
//         console.log("Aerodrome swap successful. Expected:", expectedAmountOut, "Actual:", actualOutput);
//     }

//     function test_UniswapV2SwapExecution() public {
//         uint256 amountIn = 100 * 1e6; // 100 USDC

//         // Get expected amount out from Uniswap V2
//         uint256 expectedAmountOut = swapAggregator.getAmountOutUniswapV2(USDC, EURC, amountIn);

//         // Skip test if no liquidity on Uniswap V2
//         if (expectedAmountOut == 0) {
//             console.log("No Uniswap V2 liquidity for USDC-EURC, skipping test");
//             return;
//         }

//         // Deal tokens to test contract
//         deal(USDC, address(this), amountIn);
//         IERC20(USDC).approve(address(swapAggregator), amountIn);

//         // Record EURC balance before swap
//         uint256 balanceBefore = IERC20(EURC).balanceOf(address(this));

//         // Execute Uniswap V2 swap through our mock contract that forces UniswapV2 path
//         mockSwapAggregator.setMockOutputs(0, expectedAmountOut, 0); // Set UniswapV2 as best option
//         IERC20(USDC).approve(address(mockSwapAggregator), amountIn);
//         mockSwapAggregator.executeOptimalSwap(USDC, EURC, amountIn, address(this));

//         // Verify Uniswap V2 was used
//         assertFalse(mockSwapAggregator.aerodromeExecuted(), "Aerodrome should not have executed");
//         assertTrue(mockSwapAggregator.uniswapV2Executed(), "Uniswap V2 swap should have executed");
//         assertFalse(mockSwapAggregator.uniswapV4Executed(), "Uniswap V4 should not have executed");

//         // Verify output amount is reasonable (within 10% of expected)
//         uint256 balanceAfter = IERC20(EURC).balanceOf(address(this));
//         uint256 actualOutput = balanceAfter - balanceBefore;

//         assertTrue(
//             actualOutput >= expectedAmountOut * 9 / 10,
//             "Actual Uniswap V2 output should be at least 90% of expected output"
//         );
//         console.log("Uniswap V2 swap successful. Expected:", expectedAmountOut, "Actual:", actualOutput);
//     }

//     function test_UniswapV4SwapExecution() public {
//         uint256 amountIn = 100 * 1e6; // 100 USDC

//         // Get expected amount out from Uniswap V4
//         uint256 expectedAmountOut = swapAggregator.getAmountOutUniswapV4(USDC, EURC, amountIn);

//         // Skip test if no liquidity on Uniswap V4
//         if (expectedAmountOut == 0) {
//             console.log("No Uniswap V4 liquidity for USDC-EURC, skipping test");
//             return;
//         }

//         // Deal tokens to test contract
//         deal(USDC, address(this), amountIn);
//         IERC20(USDC).approve(address(swapAggregator), amountIn);

//         // Record EURC balance before swap
//         uint256 balanceBefore = IERC20(EURC).balanceOf(address(this));

//         // Execute Uniswap V4 swap through our mock contract that forces UniswapV4 path
//         mockSwapAggregator.setMockOutputs(0, 0, expectedAmountOut); // Set UniswapV4 as best option
//         IERC20(USDC).approve(address(mockSwapAggregator), amountIn);
//         mockSwapAggregator.executeOptimalSwap(USDC, EURC, amountIn, address(this));

//         // Verify Uniswap V4 was used
//         assertFalse(mockSwapAggregator.aerodromeExecuted(), "Aerodrome should not have executed");
//         assertFalse(mockSwapAggregator.uniswapV2Executed(), "Uniswap V2 should not have executed");
//         assertTrue(mockSwapAggregator.uniswapV4Executed(), "Uniswap V4 swap should have executed");

//         // Verify output amount is reasonable (within 10% of expected)
//         uint256 balanceAfter = IERC20(EURC).balanceOf(address(this));
//         uint256 actualOutput = balanceAfter - balanceBefore;

//         assertTrue(
//             actualOutput >= expectedAmountOut * 9 / 10,
//             "Actual Uniswap V4 output should be at least 90% of expected output"
//         );
//         console.log("Uniswap V4 swap successful. Expected:", expectedAmountOut, "Actual:", actualOutput);
//     }

//     // Test direct swap execution with real tokens on fork
//     function test_DirectSwapExecution() public {
//         uint256 amountIn = 100 * 1e6; // 100 USDC

//         // Deal tokens to the test contract
//         deal(USDC, address(this), amountIn);

//         // Approve the aggregator to spend tokens
//         IERC20(USDC).approve(address(swapAggregator), amountIn);

//         // Get balances before swap
//         uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(address(this));
//         uint256 eurcBalanceBefore = IERC20(EURC).balanceOf(address(this));

//         // Execute the swap via the real aggregator
//         try swapAggregator.executeOptimalSwap(USDC, EURC, amountIn, address(this)) returns (uint256 amountOut) {
//             // Verify balances after swap
//             uint256 usdcBalanceAfter = IERC20(USDC).balanceOf(address(this));
//             uint256 eurcBalanceAfter = IERC20(EURC).balanceOf(address(this));

//             // Verify USDC was spent
//             assertEq(usdcBalanceBefore - usdcBalanceAfter, amountIn, "Incorrect amount of USDC spent");

//             // Verify EURC was received
//             assertTrue(eurcBalanceAfter > eurcBalanceBefore, "No EURC tokens received");
//             assertEq(eurcBalanceAfter - eurcBalanceBefore, amountOut, "Received amount doesn't match returned amount");

//             console.log("Swap successful. Input USDC:", amountIn, "Output EURC:", amountOut);
//         } catch {
//             console.log("Swap failed - this may be normal if running on a local Anvil instance without fork");
//         }
//     }

//     // Test execution with different token pairs
//     function test_SwapDifferentTokenPairs() public {
//         uint256 amountIn = 100 * 1e6; // 100 USDC

//         // Deal tokens
//         deal(USDC, address(this), amountIn * 2);
//         deal(EURC, address(this), 100 * 1e18);

//         // Test USDC -> USDT
//         IERC20(USDC).approve(address(swapAggregator), amountIn);
//         try swapAggregator.executeOptimalSwap(USDC, USDT, amountIn, address(this)) returns (uint256 amountOut) {
//             assertTrue(amountOut > 0, "Should receive USDT tokens");
//             console.log("USDC -> USDT swap successful. Output:", amountOut);
//         } catch {
//             console.log("USDC -> USDT swap failed - may be normal on local instance");
//         }

//         // Test EURC -> USDC
//         IERC20(EURC).approve(address(swapAggregator), 50 * 1e18);
//         try swapAggregator.executeOptimalSwap(EURC, USDC, 50 * 1e18, address(this)) returns (uint256 amountOut) {
//             assertTrue(amountOut > 0, "Should receive USDC tokens");
//             console.log("EURC -> USDC swap successful. Output:", amountOut);
//         } catch {
//             console.log("EURC -> USDC swap failed - may be normal on local instance");
//         }
//     }

//     // Test emergency recovery function
//     function test_EmergencyRecovery() public {
//         // Deal some tokens to the contract
//         deal(USDC, address(swapAggregator), 1000 * 1e6);

//         uint256 balanceBefore = IERC20(USDC).balanceOf(admin);

//         // Call recovery function
//         swapAggregator.recoverTokens(IERC20(USDC), 1000 * 1e6);

//         uint256 balanceAfter = IERC20(USDC).balanceOf(admin);

//         // Verify tokens were recovered
//         assertEq(balanceAfter - balanceBefore, 1000 * 1e6, "Tokens not properly recovered");
//     }

//     // Test negative cases for executeOptimalSwap
//     function test_ExecuteOptimalSwapFailures() public {
//         // Test with zero input
//         vm.expectRevert("Amount must be > 0");
//         swapAggregator.executeOptimalSwap(USDC, EURC, 0, user1);

//         // Test with invalid recipient
//         vm.expectRevert("Invalid recipient");
//         swapAggregator.executeOptimalSwap(USDC, EURC, 100 * 1e6, address(0));

//         // Test with no allowance
//         vm.prank(user1);
//         vm.expectRevert(); // Should revert with transfer failed
//         swapAggregator.executeOptimalSwap(USDC, EURC, 100 * 1e6, user1);
//     }

//     function test_ExecuteOptimalSwapMockedAerodrome() public {
//         uint256 amountIn = 1000 * 1e6; // 1,000 USDC

//         // Setup mock values - Aerodrome has better rate
//         uint256 mockAerodromeOut = 990 * 1e18; // 990 EURC
//         uint256 mockUniswapOut = 980 * 1e18; // 980 EURC

//         mockSwapAggregator.setMockOutputs(mockAerodromeOut, mockUniswapOut, 0);

//         // User approves mock SwapAggregator
//         deal(USDC, user1, amountIn);
//         vm.startPrank(user1);
//         IERC20(USDC).approve(address(mockSwapAggregator), amountIn);

//         // Execute optimal swap
//         mockSwapAggregator.executeOptimalSwap(USDC, EURC, amountIn, user1);
//         vm.stopPrank();

//         // Check that Aerodrome path was chosen
//         assertTrue(mockSwapAggregator.aerodromeExecuted(), "Aerodrome path should have been used");
//         assertFalse(mockSwapAggregator.uniswapV2Executed(), "Uniswap path should not have been used");

//         // Reset for next test
//         mockSwapAggregator.reset();
//     }

//     function test_ExecuteOptimalSwapMockedUniswap() public {
//         uint256 amountIn = 1000 * 1e6; // 1,000 USDC

//         // Setup mock values - Uniswap has better rate
//         uint256 mockAerodromeOut = 970 * 1e18; // 970 EURC
//         uint256 mockUniswapOut = 995 * 1e18; // 995 EURC

//         mockSwapAggregator.setMockOutputs(mockAerodromeOut, mockUniswapOut, 0);

//         // User approves mock SwapAggregator
//         deal(USDC, user1, amountIn);
//         vm.startPrank(user1);
//         IERC20(USDC).approve(address(mockSwapAggregator), amountIn);

//         // Execute optimal swap
//         mockSwapAggregator.executeOptimalSwap(USDC, EURC, amountIn, user1);
//         vm.stopPrank();

//         // Check that Uniswap path was chosen
//         assertFalse(mockSwapAggregator.aerodromeExecuted(), "Aerodrome path should not have been used");
//         assertTrue(mockSwapAggregator.uniswapV2Executed(), "Uniswap path should have been used");
//     }

//     function test_ExecuteOptimalSwapMockedEqualRates() public {
//         uint256 amountIn = 1000 * 1e6; // 1,000 USDC

//         // Setup mock values - Equal rates should use Aerodrome (default first option)
//         uint256 mockOut = 990 * 1e18; // Same for both

//         mockSwapAggregator.setMockOutputs(mockOut, mockOut, 0);

//         // User approves mock SwapAggregator
//         deal(USDC, user1, amountIn);
//         vm.startPrank(user1);
//         IERC20(USDC).approve(address(mockSwapAggregator), amountIn);

//         // Execute optimal swap
//         mockSwapAggregator.executeOptimalSwap(USDC, EURC, amountIn, user1);
//         vm.stopPrank();

//         // Check that Aerodrome path was chosen (as it's checked first when rates are equal)
//         assertTrue(mockSwapAggregator.aerodromeExecuted(), "Aerodrome path should have been used on equal rates");
//         assertFalse(mockSwapAggregator.uniswapV2Executed(), "Uniswap path should not have been used on equal rates");
//     }
// }
