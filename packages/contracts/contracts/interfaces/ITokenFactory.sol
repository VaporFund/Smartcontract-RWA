import "./IYieldBearingToken.sol";
import "./IElasticToken.sol";

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ITokenFactory {
    function createToken(string memory tokenName, string memory tokenSymbol, uint8 tokenDecimals, address owner) external returns (IElasticToken newToken);

    function createYieldBearingToken(string memory tokenName, string memory tokenSymbol, uint8 tokenDecimals, address owner) external returns (IYieldBearingToken newToken);
}
