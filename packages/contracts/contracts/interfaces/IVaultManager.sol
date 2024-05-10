// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVaultManager {
    struct Order {
        address baseToken;
        address pairToken;
        address beneficialAddress;
        bool active;
        bool enabled;
    }

    function setupNewOrder(address _tokenAddress, address _pairToken) external;

    function disableOrder(address _baseToken) external;

    function enableOrder(address _baseToken) external;

    function getOrder(address _baseToken) external view returns (Order memory);

    function paused() external view returns (bool);

    function limitLpIns(address _baseToken) external view returns (uint256);

    function maxRebasePercentPerHour(address _baseToken) external view returns (uint256);

    function BASIC_POINT() external pure returns (uint256);
}
