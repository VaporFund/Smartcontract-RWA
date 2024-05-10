// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IYieldTokenTellerV2 {
    // Buy Functions
    function buy(uint256 _amount) external returns (uint256 amount);

    function buyFor(uint256 _amount, address _recipient) external returns (uint256 amount);

    function buyPreview(uint256 _amount) external view returns (uint256 payout, uint256 fee, int256 price);

    // Sell Functions
    function sell(uint256 _amount) external returns (uint256 payout);

    function sellFor(uint256 _amount, address _recipient) external returns (uint256 payout);

    function sellPreview(uint256 _amount) external view returns (uint256 payout, uint256 fee, int256 price);
}
