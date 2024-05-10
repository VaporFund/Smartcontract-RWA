// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMockDepositPool {
    function rTokenAddress() external view returns (address);

    function deposit() external payable returns (uint256);

    function depositUsdc(uint256 amountIn) external;

    function withdraw(address recipient, uint256 amount) external returns (uint256);

    function withdrawUsdc(address recipient, uint256 amount) external;
}
