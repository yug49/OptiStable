// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAerodromeFactory {
    function allPoolsLength() external view returns (uint256);
    function allPools(uint256) external view returns (address);
    function isPaused() external view returns (bool);
    function isPair(address pair) external view returns (bool);
    function isPool(address pool) external view returns (bool);
    function getPool(address tokenA, address tokenB, bool stable) external view returns (address);
    function createPool(address tokenA, address tokenB, bool stable) external returns (address pool);
    function getFee(address pool, bool stable) external view returns (uint256);
    function voter() external view returns (address);

    // Additional functions for CLAMM pools if they exist
    function poolSpecificInfo(address pool) external view returns (uint256 poolType, uint256 ampFactor);
}
