// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Pool} from "../src/Pool.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

/**
 * @title DeployPool
 * @author Yug Agarwal
 * @notice This script is used to deploy the Pool contract and log its address and the address of the oTokens registry.
 */
contract DeployPool is Script {
    Pool public pool;
    HelperConfig public helperConfig;

    function run() external {
        vm.startBroadcast();
        pool = new Pool();
        helperConfig = new HelperConfig();
        vm.stopBroadcast();

        console.log("Pool deployed to: ", address(pool));
        console.log("OTokens Registry deployed to: ", address(pool.oTokensRegistry()));
        console.log("HelperConfig deployed to: ", address(helperConfig));
    }
}
