// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IHashnoteHelper {
    function teller() external view returns (address);

    function buyPreview(
        uint256 _stableTokenToken
    ) external view returns (uint256 _yieldToken, uint256 _fee, int256 _price);

    function sellPreview(
        uint256 _yieldToken
    ) external view returns (uint256 _stableTokenToken, uint256 _fee, int256 _price);

    function calculationPercentInterestPerRound() external view returns (uint256 _percent, int256 _price);

    function getTotalStableTokenByYieldToken(address _vault) external view returns (uint256);

    function encodeCallBuyFor(uint256 _amount, address _recipient) external pure returns (bytes memory);

    function encodeCallSellFor(uint256 _amount, address _recipient) external pure returns (bytes memory);
}
