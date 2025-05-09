// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {VaultManager} from "../src/VaultManager.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {IRouter} from "../lib/contracts/contracts/interfaces/IRouter.sol";

// Import constants
import {AERODROME_ROUTER} from "../src/Constants.sol";

contract AerodromeIntegrationTest is Test {
    // Contracts
    VaultManager public vaultManager;

    // Base Mainnet token addresses
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    //address public constant USDT = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    address public constant EURC = 0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42;
    //address public constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;

    // User addresses
    address public user1 = address(1);
    address public admin;

    // LP token address (will be determined at runtime)
    address public LP_TOKEN;

    function setUp() public {
        // Fork Base Mainnet
        // vm.createSelectFork("base_mainnet");

        // Deploy VaultManager with Aerodrome Router address
        vaultManager = new VaultManager(AERODROME_ROUTER);
        admin = address(this);

        // Get LP token address for USDC/EURC pair
        IRouter router = IRouter(AERODROME_ROUTER);
        LP_TOKEN = router.poolFor(
            USDC,
            EURC,
            true, // stable
            router.defaultFactory()
        );

        console.log("LP Token Address:", LP_TOKEN);

        vm.deal(user1, 10 ether);

        // Deal tokens directly to users instead of using whales
        // For USDC - 6 decimals
        deal(USDC, user1, 10_000 * 1e18);
        // For EURC - 18 decimals
        deal(EURC, user1, 10_000 * 1e18);

        console.log("User1 USDC Balance:", IERC20(USDC).balanceOf(user1));
        console.log("User1 EURC Balance:", IERC20(EURC).balanceOf(user1));
    }

    function test_InvestInAerodrome() public {
        // User deposits tokens to vault
        uint256 depositUSDC = 1_000 * 1e6; // 1,000 USDC
        uint256 depositEURC = 1_000 * 1e6; // 1,000 EURC

        vm.startPrank(user1);

        IERC20(USDC).approve(address(vaultManager), depositUSDC);
        vaultManager.deposit(IERC20(USDC), depositUSDC);

        IERC20(EURC).approve(address(vaultManager), depositEURC);
        vaultManager.deposit(IERC20(EURC), depositEURC);

        vm.stopPrank();

        // Check user balances in vault
        assertEq(vaultManager.userBalances(user1, USDC), depositUSDC, "USDC balance in vault incorrect");
        assertEq(vaultManager.userBalances(user1, EURC), depositEURC, "EURC balance in vault incorrect");

        // Admin invests in Aerodrome
        uint256 vaultUSDCBefore = IERC20(USDC).balanceOf(address(vaultManager));
        uint256 vaultEURCBefore = IERC20(EURC).balanceOf(address(vaultManager));
        uint256 vaultLPBefore = IERC20(LP_TOKEN).balanceOf(address(vaultManager));

        console.log("Vault USDC before invest:", vaultUSDCBefore);
        console.log("Vault EURC before invest:", vaultEURCBefore);
        console.log("Vault LP before invest:", vaultLPBefore);

        // Invest half of what was deposited
        uint256 investUSDC = 500 * 1e6; // 500 USDC
        uint256 investEURC = 500 * 1e18; // 500 EURC

        vm.prank(admin);
        uint256 liquidityReceived = vaultManager.investInAerodrome(IERC20(USDC), IERC20(EURC), investUSDC, investEURC);

        // Check balances after investment
        uint256 vaultUSDCAfter = IERC20(USDC).balanceOf(address(vaultManager));
        uint256 vaultEURCAfter = IERC20(EURC).balanceOf(address(vaultManager));
        uint256 vaultLPAfter = IERC20(LP_TOKEN).balanceOf(address(vaultManager));

        console.log("Vault USDC after invest:", vaultUSDCAfter);
        console.log("Vault EURC after invest:", vaultEURCAfter);
        console.log("Vault LP after invest:", vaultLPAfter);
        console.log("Liquidity received:", liquidityReceived);

        // Assertions
        assertTrue(vaultUSDCBefore - vaultUSDCAfter <= investUSDC, "Too much USDC spent");
        assertTrue(vaultEURCBefore - vaultEURCAfter <= investEURC, "Too much EURC spent");
        assertTrue(vaultLPAfter > vaultLPBefore, "No LP tokens received");
        assertEq(
            vaultManager.getLPTokenHoldings(LP_TOKEN), liquidityReceived, "LP token holdings not tracked correctly"
        );
    }

    function test_RedeemFromAerodrome() public {
        // First invest to get LP tokens
        test_InvestInAerodrome();

        // Get LP token balance
        uint256 lpBalance = vaultManager.getLPTokenHoldings(LP_TOKEN);
        assertTrue(lpBalance > 0, "No LP tokens to redeem");

        // Record balances before redemption
        uint256 vaultUSDCBefore = IERC20(USDC).balanceOf(address(vaultManager));
        uint256 vaultEURCBefore = IERC20(EURC).balanceOf(address(vaultManager));

        console.log("Vault USDC before redeem:", vaultUSDCBefore);
        console.log("Vault EURC before redeem:", vaultEURCBefore);
        console.log("LP balance before redeem:", lpBalance);

        // Check if LP token is properly mapped to tokens
        address token0 = vaultManager.lpTokenUnderlyingTokens(LP_TOKEN, 0);
        address token1 = vaultManager.lpTokenUnderlyingTokens(LP_TOKEN, 1);

        // If not already mapped, set it manually (in production this would happen during investInAerodrome)
        if (token0 == address(0) || token1 == address(0)) {
            vm.prank(admin);
            vaultManager.setLPTokenUnderlyingTokens(LP_TOKEN, USDC, EURC);
        }

        // Redeem half of the LP tokens
        uint256 redeemAmount = lpBalance / 2;

        vm.prank(admin);
        (uint256 amountA, uint256 amountB) = vaultManager.redeemFromAerodrome(LP_TOKEN, redeemAmount);

        // Check balances after redemption
        uint256 vaultUSDCAfter = IERC20(USDC).balanceOf(address(vaultManager));
        uint256 vaultEURCAfter = IERC20(EURC).balanceOf(address(vaultManager));
        uint256 lpBalanceAfter = vaultManager.getLPTokenHoldings(LP_TOKEN);

        console.log("Vault USDC after redeem:", vaultUSDCAfter);
        console.log("Vault EURC after redeem:", vaultEURCAfter);
        console.log("LP balance after redeem:", lpBalanceAfter);
        console.log("USDC received:", amountA);
        console.log("EURC received:", amountB);

        // Assertions
        assertTrue(vaultUSDCAfter > vaultUSDCBefore, "USDC balance should increase after redemption");
        assertTrue(vaultEURCAfter > vaultEURCBefore, "EURC balance should increase after redemption");
        assertEq(lpBalanceAfter, lpBalance - redeemAmount, "LP token balance not correctly updated");
    }
}
