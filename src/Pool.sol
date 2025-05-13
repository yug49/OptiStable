// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IOToken} from "./interfaces/OToken/IOToken.sol";
import {OTokensRegistry} from "./OTokensRegistry.sol";

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
    error Pool__AdditionFailed(address _token, address _oToken);
    error Pool__RemoveFailed(address _token, address _oToken);

    enum LockStatus {
        UNLOCKED,
        LOCKED
    }

    LockStatus private status;
    mapping(address => uint256) private liquidityTokenBalances;
    OTokensRegistry public oTokensRegistry;

    modifier lock() {
        if (status == LockStatus.LOCKED) {
            revert Pool__Locked();
        }
        status = LockStatus.LOCKED;
        _;
        status = LockStatus.UNLOCKED;
    }

    modifier onlyAllowedToken(address _token) {
        if (oTokensRegistry.tokenToOToken(_token) == address(0)) {
            revert Pool__TokenAddressInvalid();
        }
        _;
    }

    modifier onlyAllowedTokens(address[] memory _tokens) {
        for (uint256 i = 0; i < _tokens.length; i++) {
            if (oTokensRegistry.tokenToOToken(_tokens[i]) == address(0)) {
                revert Pool__TokenAddressInvalid();
            }
        }
        _;
    }

    constructor() Ownable(msg.sender) {
        oTokensRegistry = new OTokensRegistry();
    }

    function addLiquidity(address _token, uint256 _amount, address _recipient)
        external
        lock
        onlyAllowedToken(_token)
        returns (bool)
    {
        if (_amount == 0) {
            revert Pool__AmountInvalid();
        }
        if (_token == address(0)) {
            revert Pool__AmountInvalid();
        }

        IERC20(_token).transferFrom(_recipient, address(this), _amount);
        liquidityTokenBalances[_token] += _amount;
        IOToken(oTokensRegistry.tokenToOToken(_token)).mint(_recipient, _amount);

        return true;
    }

    function removeLiquidity(address _token, uint256 _amount, address _recipient)
        external
        lock
        onlyAllowedToken(_token)
        returns (bool)
    {
        if (_amount == 0) {
            revert Pool__AmountInvalid();
        }
        if (_token == address(0)) {
            revert Pool__AmountInvalid();
        }

        IOToken(oTokensRegistry.tokenToOToken(_token)).transferFrom(_recipient, address(this), _amount);
        IOToken(oTokensRegistry.tokenToOToken(_token)).burn(_amount);
        IERC20(_token).transferFrom(address(this), _recipient, _amount);
        liquidityTokenBalances[_token] -= _amount;
        IOToken(oTokensRegistry.tokenToOToken(_token)).burn(_amount);

        return true;
    }

    function addAllowedTokens(address _token, address _oToken) external lock onlyOwner returns (bool) {
        if (_token == address(0)) {
            revert Pool__AmountInvalid();
        }

        if (!oTokensRegistry.addTokenPair(_token, _oToken)) {
            revert Pool__AdditionFailed(_token, _oToken);
        }
        return true;
    }

    function removeAllowedTokens(address _token) external lock onlyOwner returns (bool) {
        if (_token == address(0)) {
            revert Pool__AmountInvalid();
        }
        if (!oTokensRegistry.removeTokenPair(_token)) {
            revert Pool__RemoveFailed(_token, address(0));
        }
        return true;
    }

    function addAllowedTokens(address[] memory _tokens, address[] memory _oTokens)
        external
        lock
        onlyOwner
        returns (bool)
    {
        if (_tokens.length != _oTokens.length) {
            revert Pool__TokensLengthShouldBeEqualToOTokensLength();
        }
        if (_tokens.length == 0) {
            revert Pool__AmountInvalid();
        }
        for (uint256 i = 0; i < _tokens.length; i++) {
            if (_tokens[i] == address(0) || _oTokens[i] == address(0)) {
                revert Pool__TokenAddressInvalid();
            }
            if (!oTokensRegistry.addTokenPair(_tokens[i], _oTokens[i])) {
                revert Pool__AdditionFailed(_tokens[i], _oTokens[i]);
            }
        }
        return true;
    }

    /* Getter Functions */

    function getOTokenAddress(address _token) external view onlyAllowedToken(_token) returns (address) {
        return oTokensRegistry.tokenToOToken(_token);
    }

    function getOTokenAddresses(address[] memory _tokens)
        external
        view
        onlyAllowedTokens(_tokens)
        returns (address[] memory)
    {
        address[] memory oTokens = new address[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            oTokens[i] = oTokensRegistry.tokenToOToken(_tokens[i]);
        }
        return oTokens;
    }
}
