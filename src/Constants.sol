// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


// BASE MAINNET
// Aerodrome
address constant AERODROME_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
address constant FACTORY_REGISTRY = 0x5C3F18F06CC09CA1910767A34a20F771039E37C0;
address constant AERODROME_MULTI_ROUTER = 0x0A5aA5D3a4d28014f967Bf0f29EAA3FF9807D5c6;
// Uniswap
address constant UNISWAP_V2_ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24; // Uniswap V2 Router on Base
address constant UNISWAP_V4_ROUTER = 0x6fF5693b99212Da76ad316178A184AB56D299b43; // Uniswap V4 Router on Base
address constant UNISWAP_V4_QUOTER = 0x0d5e0F971ED27FBfF6c2837bf31316121532048D;
address constant UNISWAP_V3_QUOTER_V2 = 0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a;
address constant UNISWAPX_ROUTER = 0x0d5e0F971ED27FBfF6c2837bf31316121532048D; // UniswapX Router on Base
address constant UNISWAP_UNIVERSAL_ROUTER = 0x6fF5693b99212Da76ad316178A184AB56D299b43; // Uniswap Universal Router on Base
// Tokens
address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
uint8 constant USDC_DECIMALS = 6;
address constant USDT = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2;
uint8 constant USDT_DECIMALS = 6;
address constant EURC = 0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42;
uint8 constant EURC_DECIMALS = 6;
address constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
uint8 constant DAI_DECIMALS = 18;

contract TickSpacings {
    int24 constant AERODROME_1 = 1;
    int24 constant AERODROME_10 = 10;
    int24 constant AERODROME_50 = 50;
    int24 constant AERODROME_100 = 100;
    int24 constant AERODROME_200 = 200;
    int24 constant AERODROME_2000 = 2000;
    
    function getAerodromeTickSpacings() public pure returns (int24[] memory) {
        int24[] memory tickSpacings = new int24[](6);
        tickSpacings[0] = AERODROME_1;
        tickSpacings[1] = AERODROME_10;
        tickSpacings[2] = AERODROME_50;
        tickSpacings[3] = AERODROME_100;
        tickSpacings[4] = AERODROME_200;
        tickSpacings[5] = AERODROME_2000;
        return tickSpacings;
    }
}