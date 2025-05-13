// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniswapXQuoter {
    // Error thrown if reactorCallback receives more than one order
    error OrdersLengthIncorrect();

    // Struct representing order information
    struct OrderInfo {
        address reactor;
        address swapper;
        uint256 nonce;
        uint256 deadline;
        address additionalValidationContract;
        bytes additionalValidationData;
    }

    // Struct for input tokens
    struct InputToken {
        address token;
        uint256 amount;
        uint256 maxAmount;
    }

    // Struct for output tokens
    struct OutputToken {
        address token;
        uint256 amount;
        address recipient;
    }

    // Complete order with all details
    struct ResolvedOrder {
        OrderInfo info;
        InputToken input;
        OutputToken[] outputs;
        bytes sig;
        bytes32 hash;
    }

    /**
     * @notice Return the reactor of a given order (abi.encoded bytes).
     * @param order abi-encoded order, including `reactor` as the first encoded struct member
     * @return reactor The reactor address
     */
    function getReactor(bytes calldata order) external pure returns (address reactor);

    /**
     * @notice Quote the given order, returning the ResolvedOrder object which defines
     * the current input and output token amounts required to satisfy it
     * Also bubbles up any reverts that would occur during the processing of the order
     * @param order abi-encoded order, including `reactor` as the first encoded struct member
     * @param sig The order signature
     * @return result The ResolvedOrder
     */
    function quote(bytes calldata order, bytes calldata sig) external returns (ResolvedOrder memory result);

    /**
     * @notice Convenience function for quoting token output amounts directly
     * @param tokenIn Address of the input token
     * @param tokenOut Address of the output token
     * @param amountIn Amount of input token
     * @return amountOut Amount of output tokens that would be received
     */
    function quoteAmountOut(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256 amountOut);

    /**
     * @notice Reactor callback function
     * @param resolvedOrders The resolved orders
     * @param extraData Additional data passed to the callback
     */
    function reactorCallback(ResolvedOrder[] calldata resolvedOrders, bytes calldata extraData) external pure;
}
