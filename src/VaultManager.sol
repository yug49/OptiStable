// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./interfaces/IERC20.sol";

contract VaultManager {
    mapping(address => mapping(address => uint256)) public userBalances; // user => token => balance

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdrawal(address indexed user, address indexed token, uint256 amount);

    function deposit(IERC20 _stablecoin, uint256 _amount) external {
        require(_amount > 0, "Deposit amount must be greater than 0");
        // Note: Actual token transfer needs to be handled here
        // For example: require(_stablecoin.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");
        userBalances[msg.sender][address(_stablecoin)] += _amount;
        emit Deposit(msg.sender, address(_stablecoin), _amount);
    }

    function withdraw(IERC20 _stablecoin, uint256 _amount) external {
        require(_amount > 0, "Withdrawal amount must be greater than 0");
        require(userBalances[msg.sender][address(_stablecoin)] >= _amount, "Insufficient balance");
        // Note: Actual token transfer needs to be handled here
        // For example: require(_stablecoin.transfer(msg.sender, _amount), "Token transfer failed");
        userBalances[msg.sender][address(_stablecoin)] -= _amount;
        emit Withdrawal(msg.sender, address(_stablecoin), _amount);
    }
}
