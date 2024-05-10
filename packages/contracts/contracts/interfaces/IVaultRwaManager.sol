// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

enum PlatformType {
    HASHNOTE
}

interface IVaultRwaManager {
    struct Order {
        address baseToken;
        address pairToken;
        uint256 minimumDeposit;
        uint8 delayBuyDay;
        uint8 delaySellDay;
        address beneficialAddress;
        PlatformType platformType;
        address platformHelper;
        bool active;
        bool enabled;
        bool redirect;
    }

    function setupNewOrder(address _tokenAddress, address _pairToken) external;

    function disableOrder(address _baseToken) external;

    function enableOrder(address _baseToken) external;

    function getOrder(address _baseToken) external view returns (Order memory);

    function paused() external view returns (bool);

    function limitLpIns(address _baseToken) external view returns (uint256);

    function maxRebasePercentPerHour(address _baseToken) external view returns (uint256);

    function BASIC_POINT() external view returns (uint256);
}
