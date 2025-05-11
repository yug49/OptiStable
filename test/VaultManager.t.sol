// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import {Test, console} from "../lib/forge-std/src/Test.sol";
// import {VaultManager} from "../src/VaultManager.sol";
// import {IERC20} from "../src/interfaces/IERC20.sol";
// import {ERC20Mock} from "../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
// import "../src/Constants.sol";

// contract VaultManagerTest is Test {
//     VaultManager public vaultManager;
//     ERC20Mock public daiStablecoin;
//     ERC20Mock public usdcStablecoin;


//     address public user1 = address(1);
//     address public user2 = address(2);

//     function setUp() public {
//         vaultManager = new VaultManager(AERODROME_ROUTER);

//         // Deploy mock stablecoins
//         daiStablecoin = new ERC20Mock();
//         usdcStablecoin = new ERC20Mock();

//         // Mint some tokens to users
//         daiStablecoin.mint(user1, 1000 * 1e18);
//         usdcStablecoin.mint(user1, 500 * 1e6); // Assuming USDC has 6 decimals

//         daiStablecoin.mint(user2, 2000 * 1e18);
//     }

//     // function test_Deposit() public {
//     //     uint256 depositAmountDAI = 100 * 1e18;
//     //     uint256 depositAmountUSDC = 50 * 1e6;

//     //     // User1 deposits DAI
//     //     vm.startPrank(user1);
//     //     daiStablecoin.approve(address(vaultManager), depositAmountDAI);
//     //     vaultManager.deposit(IERC20(address(daiStablecoin)), depositAmountDAI);
//     //     vm.stopPrank();

//     //     assertEq(
//     //         vaultManager.userBalances(user1, address(daiStablecoin)),
//     //         depositAmountDAI,
//     //         "DAI balance for user1 should be updated after deposit"
//     //     );
//     //     assertEq(
//     //         daiStablecoin.balanceOf(address(vaultManager)), depositAmountDAI, "VaultManager DAI balance should increase"
//     //     );
//     //     assertEq(daiStablecoin.balanceOf(user1), (1000 * 1e18) - depositAmountDAI, "User1 DAI balance should decrease");

//     //     // User1 deposits USDC
//     //     vm.startPrank(user1);
//     //     usdcStablecoin.approve(address(vaultManager), depositAmountUSDC);
//     //     vaultManager.deposit(IERC20(address(usdcStablecoin)), depositAmountUSDC);
//     //     vm.stopPrank();

//     //     assertEq(
//     //         vaultManager.userBalances(user1, address(usdcStablecoin)),
//     //         depositAmountUSDC,
//     //         "USDC balance for user1 should be updated after deposit"
//     //     );
//     //     assertEq(
//     //         usdcStablecoin.balanceOf(address(vaultManager)),
//     //         depositAmountUSDC,
//     //         "VaultManager USDC balance should increase"
//     //     );
//     //     assertEq(usdcStablecoin.balanceOf(user1), (500 * 1e6) - depositAmountUSDC, "User1 USDC balance should decrease");
//     // }

//     // function test_Withdraw() public {
//     //     uint256 initialDepositDAI = 200 * 1e18;
//     //     uint256 withdrawAmountDAI = 50 * 1e18;

//     //     // User1 deposits DAI first
//     //     vm.startPrank(user1);
//     //     daiStablecoin.approve(address(vaultManager), initialDepositDAI);
//     //     vaultManager.deposit(IERC20(address(daiStablecoin)), initialDepositDAI);
//     //     vm.stopPrank();

//     //     // User1 withdraws DAI
//     //     vm.startPrank(user1);
//     //     vaultManager.withdraw(IERC20(address(daiStablecoin)), withdrawAmountDAI);
//     //     vm.stopPrank();

//     //     assertEq(
//     //         vaultManager.userBalances(user1, address(daiStablecoin)),
//     //         initialDepositDAI - withdrawAmountDAI,
//     //         "DAI balance for user1 should be updated after withdrawal"
//     //     );
//     //     assertEq(
//     //         daiStablecoin.balanceOf(address(vaultManager)),
//     //         initialDepositDAI - withdrawAmountDAI,
//     //         "VaultManager DAI balance should decrease after withdrawal"
//     //     );
//     //     assertEq(
//     //         daiStablecoin.balanceOf(user1),
//     //         (1000 * 1e18) - initialDepositDAI + withdrawAmountDAI,
//     //         "User1 DAI balance should increase after withdrawal"
//     //     );
//     // }

//     function test_BalanceUpdates() public {
//         uint256 deposit1AmountDAI_user1 = 100 * 1e18;
//         uint256 deposit2AmountDAI_user1 = 50 * 1e18;
//         uint256 deposit1AmountDAI_user2 = 300 * 1e18;

//         // User1 deposits DAI
//         vm.startPrank(user1);
//         daiStablecoin.approve(address(vaultManager), deposit1AmountDAI_user1);
//         vaultManager.deposit(IERC20(address(daiStablecoin)), deposit1AmountDAI_user1);
//         vm.stopPrank();

//         assertEq(vaultManager.userBalances(user1, address(daiStablecoin)), deposit1AmountDAI_user1);

//         // User1 deposits more DAI
//         vm.startPrank(user1);
//         daiStablecoin.approve(address(vaultManager), deposit2AmountDAI_user1);
//         vaultManager.deposit(IERC20(address(daiStablecoin)), deposit2AmountDAI_user1);
//         vm.stopPrank();

//         assertEq(
//             vaultManager.userBalances(user1, address(daiStablecoin)), deposit1AmountDAI_user1 + deposit2AmountDAI_user1
//         );

//         // User2 deposits DAI
//         vm.startPrank(user2);
//         daiStablecoin.approve(address(vaultManager), deposit1AmountDAI_user2);
//         vaultManager.deposit(IERC20(address(daiStablecoin)), deposit1AmountDAI_user2);
//         vm.stopPrank();

//         assertEq(vaultManager.userBalances(user2, address(daiStablecoin)), deposit1AmountDAI_user2);
//         // Ensure User1's balance is unaffected by User2's deposit
//         assertEq(
//             vaultManager.userBalances(user1, address(daiStablecoin)), deposit1AmountDAI_user1 + deposit2AmountDAI_user1
//         );
//     }

//     function test_Fail_DepositZeroAmount() public {
//         vm.startPrank(user1);
//         daiStablecoin.approve(address(vaultManager), 100 * 1e18); // Approve some amount
//         vm.expectRevert("Deposit amount must be greater than 0");
//         vaultManager.deposit(IERC20(address(daiStablecoin)), 0);
//         vm.stopPrank();
//     }

//     function test_Fail_WithdrawZeroAmount() public {
//         // User1 deposits DAI first
//         vm.startPrank(user1);
//         daiStablecoin.approve(address(vaultManager), 100 * 1e18);
//         vaultManager.deposit(IERC20(address(daiStablecoin)), 100 * 1e18);
//         vm.stopPrank();

//         vm.startPrank(user1);
//         vm.expectRevert("Withdrawal amount must be greater than 0");
//         vaultManager.withdraw(IERC20(address(daiStablecoin)), 0);
//         vm.stopPrank();
//     }

//     function test_Fail_WithdrawInsufficientBalance() public {
//         // User1 deposits DAI first
//         vm.startPrank(user1);
//         daiStablecoin.approve(address(vaultManager), 50 * 1e18);
//         vaultManager.deposit(IERC20(address(daiStablecoin)), 50 * 1e18);
//         vm.stopPrank();

//         vm.startPrank(user1);
//         vm.expectRevert("Insufficient balance");
//         vaultManager.withdraw(IERC20(address(daiStablecoin)), 100 * 1e18); // Trying to withdraw more than deposited
//         vm.stopPrank();
//     }

//     // Test events
//     function test_Deposit_EmitsEvent() public {
//         uint256 depositAmount = 100 * 1e18;
//         vm.startPrank(user1);
//         daiStablecoin.approve(address(vaultManager), depositAmount);

//         vm.expectEmit(true, true, true, true);
//         emit VaultManager.Deposit(user1, address(daiStablecoin), depositAmount);
//         vaultManager.deposit(IERC20(address(daiStablecoin)), depositAmount);
//         vm.stopPrank();
//     }

//     function test_Withdraw_EmitsEvent() public {
//         uint256 depositAmount = 100 * 1e18;
//         uint256 withdrawAmount = 50 * 1e18;

//         // Deposit first
//         vm.startPrank(user1);
//         daiStablecoin.approve(address(vaultManager), depositAmount);
//         vaultManager.deposit(IERC20(address(daiStablecoin)), depositAmount);
//         vm.stopPrank();

//         // Withdraw
//         vm.startPrank(user1);
//         vm.expectEmit(true, true, true, true);
//         emit VaultManager.Withdrawal(user1, address(daiStablecoin), withdrawAmount);
//         vaultManager.withdraw(IERC20(address(daiStablecoin)), withdrawAmount);
//         vm.stopPrank();
//     }
// }
