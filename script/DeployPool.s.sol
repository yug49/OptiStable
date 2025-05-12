// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Pool} from "../src/Pool.sol";

/**
 * @title DeployPool
 * @author Yug Agarwal
 * @notice This script is used to deploy the Pool contract and log its address and the address of the oTokens registry.
 */

contract DeployPool is Script {
    // HelperConfig public helperConfig;
    Pool public pool;

    function run()
        external
    {
        vm.startBroadcast(msg.sender);
        pool = new Pool();
        vm.stopBroadcast();

        console.log("Pool deployed to: ", address(pool));
        console.log("OTokens Registry: ", address(pool.oTokensRegistry()));
    }
}
