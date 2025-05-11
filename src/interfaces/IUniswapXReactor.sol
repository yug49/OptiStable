// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUniswapXReactor {
    struct SignedOrder {
        bytes order;
        bytes sig;
    }

    function execute(SignedOrder calldata order) external payable;
    function executeBatch(SignedOrder[] calldata orders) external payable;
    function executeWithCallback(SignedOrder calldata order, bytes calldata callbackData) external payable;
    function executeBatchWithCallback(SignedOrder[] calldata orders, bytes calldata callbackData) external payable;
}