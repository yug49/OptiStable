// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {ERC20Mock} from "../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

/**
 * @title HelperConfig
 * @author Yug Agarwal
 * @notice This contract is used to manage the configuration of the helper scripts.
 */
contract HelperConfig is Script {
    error HelperConfig__ChainIdNotSupported();

    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 31337) {
            getOrCreateAnvilNetworkConfig();
        } else if (block.chainid == 84532) {
            getSepoliaBaseNetworkConfig();
        } else if (block.chainid == 8453) {
            getBaseNetworkConfig();
        } else {
            revert HelperConfig__ChainIdNotSupported();
        }
    }

    function getOrCreateAnvilNetworkConfig() internal {
        vm.startBroadcast();
        // deploy the mocks...
        ERC20Mock mockUSDC = new ERC20Mock();
        ERC20Mock mockEURC = new ERC20Mock();
        vm.stopBroadcast();

        console.log("Mock USDC deployed to: ", address(mockUSDC));
        console.log("Mock EURC deployed to: ", address(mockEURC));

        mockUSDC.mint(msg.sender, 10000 * 1e6);
        mockEURC.mint(msg.sender, 10000 * 1e6);
    }

    function getSepoliaBaseNetworkConfig() internal view {}

    function getBaseNetworkConfig() internal view {}
}
