// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface RockXStaking {
    function mint(uint256 minToMint, uint256 deadline) external payable returns (uint256 minted);

    function redeemFromValidators(uint256 ethersToRedeem, uint256 maxToBurn, uint256 deadline) external returns (uint256 burned);
}
