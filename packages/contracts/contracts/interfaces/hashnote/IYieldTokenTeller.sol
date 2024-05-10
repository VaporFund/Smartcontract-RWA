// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IYieldTokenTeller {
    function liquidityProvider() external view returns (address);

    function setLiquidityProvider(address _liquidityProvider) external;

    function fund(uint256 _amount) external;

    function redeem(uint256 _ytokenAmount, uint256 _stableAmount) external;

    function setTradingHours(uint256 _startHour, uint256 _endHour) external;

    function buy(uint256 _amount) external returns (uint256);

    function buyFor(uint256 _amount, address _recipient) external returns (uint256);

    function sell(uint256 _amount) external returns (uint256);

    function sellFor(uint256 _amount, address _recipient) external returns (uint256);

    function sellPreview(uint256 _amount) external view returns (uint256 payout, uint256 fee, int256 price);
}
