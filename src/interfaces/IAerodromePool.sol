// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAerodromePool {
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function stable() external view returns (bool);
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
    function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast);
    function metadata()
        external
        view
        returns (uint256 dec0, uint256 dec1, uint256 r0, uint256 r1, bool st, address t0, address t1);
    function claimFees() external returns (uint256, uint256);
    function tokens() external view returns (address, address);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function mint(address to) external returns (uint256 liquidity);
}
