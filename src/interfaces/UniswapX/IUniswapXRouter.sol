// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUniswapXRouter {
    function fill(bytes calldata order, bytes calldata signature) external payable;
}
