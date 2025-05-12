// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract OTokensRegistry is Ownable {
    error OTokensRegistry__NotZeroAddress();
    error OTokensRegistry__NotValidToken();
    error OTokensRegistry__NotValidTokenPair();
    error OTokensRegistry__NotValidOToken();
    error OTokensRegistry__OTokenAlreadyAvailable(address oToken);

    event TokenPairAdded(address indexed token, address indexed oToken);
    event TokenPairRemoved(address indexed token, address indexed oToken);

    constructor() Ownable(msg.sender) {}

    struct TokenPairs{
        address token;
        address oToken;
    }

    TokenPairs[] private tokensPairs;

    function tokenToOToken(address _token) external view returns (address) {
        for (uint256 i = 0; i < tokensPairs.length; i++) {
            if (tokensPairs[i].token == _token) {
                return tokensPairs[i].oToken;
            }
        }
        revert OTokensRegistry__NotValidToken();
    }

    function oTokenToToken(address _oToken) external view returns (address) {
        for (uint256 i = 0; i < tokensPairs.length; i++) {
            if (tokensPairs[i].oToken == _oToken) {
                return tokensPairs[i].token;
            }
        }
        revert OTokensRegistry__NotValidOToken();
    }

    function addTokenPair(address _token, address _oToken) external onlyOwner returns (bool) {
        if (_token == address(0) || _oToken == address(0)) {
            revert OTokensRegistry__NotZeroAddress();
        }
        if( _token == _oToken) {
            revert OTokensRegistry__NotValidTokenPair();
        }
        for (uint256 i = 0; i < tokensPairs.length; i++) {
            if (tokensPairs[i].token == _token) {
                revert OTokensRegistry__OTokenAlreadyAvailable(tokensPairs[i].oToken);
            }
        }
        tokensPairs.push(TokenPairs(_token, _oToken));

        emit TokenPairAdded(_token, _oToken);
        return true;
    }

    function removeTokenPair(address _token) external onlyOwner returns (bool) {
        if(_token == address(0)) {
            revert OTokensRegistry__NotZeroAddress();
        }
        
        for (uint256 i = 0; i < tokensPairs.length; i++) {
            if (tokensPairs[i].token == _token) {
                emit TokenPairRemoved(_token, tokensPairs[i].oToken);
                tokensPairs[i] = tokensPairs[tokensPairs.length - 1];
                tokensPairs.pop();
                return true;
            }
        }
        return false;
    }
}