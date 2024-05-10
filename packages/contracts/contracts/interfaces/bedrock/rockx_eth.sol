// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../IERC20Metadata.sol";

interface RockXETH is IERC20Metadata {
    function mint(address account, uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;

    function pause() external;

    function unpause() external;
}
