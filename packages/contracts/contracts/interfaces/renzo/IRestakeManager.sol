// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

interface IRestakeManager {
    function depositETH(uint256 _referralId) external;

    function getOperatorDelegatorsLength() external view returns (uint256);

    function calculateTVLs() external view returns (uint256[][] memory, uint256[] memory, uint256);
}
