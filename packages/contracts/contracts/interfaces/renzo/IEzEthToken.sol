// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "../IERC20Metadata.sol";

interface IEzEthToken is IERC20Metadata {
    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}
