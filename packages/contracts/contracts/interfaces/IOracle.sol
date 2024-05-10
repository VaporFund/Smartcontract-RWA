// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOracle {
    function getData(address _tokenA, address _tokenB) external view returns (uint256, uint256, uint256, uint256);
}
