// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {oETH} from "../src/OTokens/oETH.sol";
import {oEURC} from "../src/OTokens/oEURC.sol";
import {oUSDC} from "../src/OTokens/oUSDC.sol";

contract DeployOTokens is Script {
    constructor() {}

    function run()
        external
        returns (
            address[] memory oTokens
        )
    {
        vm.startBroadcast(msg.sender);
        oETH _oETH = new oETH();
        console.log("oETH deployed to: ", address(_oETH));
        oEURC _oEURC = new oEURC();
        console.log("oEURC deployed to: ", address(_oEURC));
        oUSDC _oUSDC = new oUSDC();
        console.log("oUSDC deployed to: ", address(_oUSDC));
        vm.stopBroadcast();

        oTokens = new address[](3);
        oTokens[0] = address(_oETH);
        oTokens[1] = address(_oEURC);
        oTokens[2] = address(_oUSDC);
    }
}
