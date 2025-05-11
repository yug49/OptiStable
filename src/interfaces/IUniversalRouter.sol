// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

interface IUniversalRouter {
    error ExecutionFailed(uint256 commandIndex, bytes message);
    error LengthMismatch();
    error TransactionDeadlinePassed();
    error InvalidEthSender();

    /// @notice Execute commands, passing along ETH value for any required purchases
    /// @param commands Series of commands to execute
    /// @param inputs Input parameters for each command
    function execute(bytes calldata commands, bytes[] calldata inputs) external payable;

    /// @notice Execute commands with a deadline, passing along ETH value for any required purchases
    /// @param commands Series of commands to execute
    /// @param inputs Input parameters for each command
    /// @param deadline Timestamp after which the transaction will fail
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
}