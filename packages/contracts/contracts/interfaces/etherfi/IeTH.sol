// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IeETH {
    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalShares() external view returns (uint256);

    function shares(address _user) external view returns (uint256);

    function balanceOf(address _user) external view returns (uint256);

    function mintShares(address _user, uint256 _share) external;

    function burnShares(address _user, uint256 _share) external;

    function transferFrom(address _sender, address _recipient, uint256 _amount) external returns (bool);

    function transfer(address _recipient, uint256 _amount) external returns (bool);

    function approve(address _spender, uint256 _amount) external returns (bool);

    function increaseAllowance(address _spender, uint256 _increaseAmount) external returns (bool);

    function decreaseAllowance(address _spender, uint256 _decreaseAmount) external returns (bool);
}
