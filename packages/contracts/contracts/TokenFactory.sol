// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./utility/ElasticToken.sol";
import "./interfaces/IElasticToken.sol";
import "./utility/YieldBearingToken.sol";
import "./interfaces/IYieldBearingToken.sol";

/*
 * @title TokenFactory
 * @dev create a new token contract and grant permission to vault.sol.
 */

contract TokenFactory {
    event TokenCreated(address indexed tokenAddress);

    /**
     * @notice Create a new token and return it to the caller.
     */
    // deploy in ethereum dont need rebase token

    function createToken(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        address owner
    ) external returns (IElasticToken newToken) {
        ElasticToken mintableToken = new ElasticToken(tokenName, tokenSymbol, tokenDecimals, owner);
        newToken = IElasticToken(address(mintableToken));

        emit TokenCreated(address(newToken));
    }

    function createYieldBearingToken(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        address owner
    ) external returns (IYieldBearingToken newToken) {
        YieldBearingToken mintableToken = new YieldBearingToken(tokenName, tokenSymbol, tokenDecimals, owner);
        newToken = IYieldBearingToken(address(mintableToken));

        emit TokenCreated(address(newToken));
    }
}
