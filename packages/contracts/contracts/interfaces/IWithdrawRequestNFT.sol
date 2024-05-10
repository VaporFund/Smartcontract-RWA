// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IWithdrawRequestNFT {
    function mint(address _token, uint256 _amount, address _recipient) external returns (uint256);

    function getTokenAmount(uint256 _id) external view returns (uint256);

    function getTokenAddress(uint256 _id) external view returns (address);

    function withdrawTo(address _token, uint256 _amount, address _recipient) external;
}
