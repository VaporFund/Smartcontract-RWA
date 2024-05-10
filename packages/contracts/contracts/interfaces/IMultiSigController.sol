// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMultiSigController {
    function submitRequest(address _contractAddress, bytes memory _data) external returns (uint32);

    function isOperator(address _operator) external returns (bool);

    function isAdmin(address _admin) external returns (bool);
}
