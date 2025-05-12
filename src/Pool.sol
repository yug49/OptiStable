// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IOToken} from "./interfaces/OToken/IOToken.sol";

/**
 * @title Pool Contract
 * @author Yug Agarwal
 * @notice This contract is used to manage the liquidity pool for the Opti tokens.
 * @dev The contract allows users to add liquidity to the pool and this liqudity can be used to swap tokens.
 */

contract Pool is Ownable {
    error Pool__Locked();
    error Pool__AmountInvalid();
    error Pool__TokensLengthShouldBeEqualToOTokensLength();
    error Pool__TokenAddressInvalid();
    error Pool__TransferOfOTokensFailed();

    enum LockStatus {
        UNLOCKED,
        LOCKED
    }

    LockStatus private status;
    mapping(address => address) private tokenToOToken;
    mapping(address => uint256) private liquidityTokenBalances;

    modifier lock() {
        if(status == LockStatus.LOCKED) {
            revert Pool__Locked();
        }
        status = LockStatus.LOCKED;
        _;
        status = LockStatus.UNLOCKED;
    }

    modifier onlyAllowedToken(address _token) {
        if(tokenToOToken[_token] == address(0)) {
            revert Pool__TokenAddressInvalid();
        }
        _;
    }

    modifier onlyAllowedTokens(address[] memory _tokens) {
        for(uint256 i = 0; i < _tokens.length; i++) {
            if(tokenToOToken[_tokens[i]] == address(0)) {
                revert Pool__TokenAddressInvalid();
            }
        }
        _;
    }

    constructor() Ownable(msg.sender) {}

    function addLiquidity(
        address _token,
        uint256 _amount,
        address _recipient
    ) external lock onlyAllowedToken(_token) returns (bool) {
        if(_amount == 0) {
            revert Pool__AmountInvalid();
        }
        if(_token == address(0)) {
            revert Pool__AmountInvalid();
        }

        IERC20(_token).transferFrom(_recipient, address(this), _amount);
        liquidityTokenBalances[_token] += _amount;
        IOToken(tokenToOToken[_token]).mint(_recipient, _amount);

        return true;
    }

    function removeLiquidity(
        address _token,
        uint256 _amount,
        address _recipient
    ) external lock onlyAllowedToken(_token) returns (bool) {
        if(_amount == 0) {
            revert Pool__AmountInvalid();
        }
        if(_token == address(0)) {
            revert Pool__AmountInvalid();
        }

        IOToken(tokenToOToken[_token]).transferFrom(_recipient, address(this), _amount);
        IOToken(tokenToOToken[_token]).burn(_amount);
        IERC20(_token).transferFrom(address(this), _recipient, _amount);
        liquidityTokenBalances[_token] -= _amount;
        IOToken(tokenToOToken[_token]).burn(_amount);

        return true;
    }
    

    function addAllowedTokens(
        address _token,
        address _oToken
    ) external lock onlyOwner returns (bool) {
        if(_token == address(0)) {
            revert Pool__AmountInvalid();
        }

        tokenToOToken[_token] = _oToken;
        return true;
    }

    function addAllowedTokens(
        address[] memory _tokens,
        address[] memory _oTokens
    ) external lock onlyOwner returns (bool) {
        if(_tokens.length != _oTokens.length) {
            revert Pool__TokensLengthShouldBeEqualToOTokensLength();
        }

        for(uint256 i = 0; i < _tokens.length; i++) {
            tokenToOToken[_tokens[i]] = _oTokens[i];
        }
        return true;
    }

    /* Getter Functions */

    function getOTokenAddress(
        address _token
    ) external view onlyAllowedToken(_token) returns (address) {
        return tokenToOToken[_token];
    }

    function getOTokenAddresses(
        address[] memory _tokens
    ) external view onlyAllowedTokens(_tokens) returns (address[] memory) {
        address[] memory oTokens = new address[](_tokens.length);
        for(uint256 i = 0; i < _tokens.length; i++) {
            oTokens[i] = tokenToOToken[_tokens[i]];
        }
        return oTokens;
    }
    
}