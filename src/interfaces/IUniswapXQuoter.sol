//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IUniswapXQuoter {
    struct TokenAmount {
        address token;
        uint256 amount;
    }
    
    struct OrderInfo {
        address reactor;
        address swapper;
        uint256 nonce;
        uint256 deadline;
        address additionalValidationContract;
        bytes additionalValidationData;
    }
    
    struct QuoteResult {
        OrderInfo info;
        TokenAmount[] input;
        TokenAmount[] outputs;
    }

    function quote(bytes memory order, bytes memory sig) external returns (QuoteResult memory result);
    function quoteAmountOut(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256 amountOut);
}