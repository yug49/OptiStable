// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract oETH is ERC20, ERC20Burnable, Ownable {
    error oETH__BurnAmountExceedsBalance();
    error oETH__NotZeroAddress();
    error oETH__BalanceMustBeMoreThanZero();

    constructor() ERC20("Opti ETH", "oETH") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert oETH__BalanceMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert oETH__BurnAmountExceedsBalance();
        }
        super.burn(_amount); //super-> calling parent's class
    }

    function mint(address _to, uint256 _amount) public onlyOwner returns (bool) {
        if (_to == address(0)) revert oETH__NotZeroAddress();
        if (_amount <= 0) revert oETH__BalanceMustBeMoreThanZero();

        _mint(_to, _amount);
        return true;
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }
}