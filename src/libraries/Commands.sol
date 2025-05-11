// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

library Commands {
    // Command Flags
    bytes1 constant FLAG_ALLOW_REVERT = 0x80;
    
    // Uniswap Commands
    bytes1 constant V3_SWAP_EXACT_IN = 0x00;
    bytes1 constant V3_SWAP_EXACT_OUT = 0x01;
    bytes1 constant V2_SWAP_EXACT_IN = 0x08;
    bytes1 constant V2_SWAP_EXACT_OUT = 0x09;
    bytes1 constant V4_SWAP_EXACT_IN = 0x3a;
    bytes1 constant V4_SWAP_EXACT_OUT = 0x3b;
    bytes1 constant PERMIT2_TRANSFER_FROM = 0x0a;
    
    // Funds handling Commands
    bytes1 constant UNWRAP_WETH = 0x0c;
    bytes1 constant WRAP_ETH = 0x0b;
    bytes1 constant SWEEP = 0x0d;
}