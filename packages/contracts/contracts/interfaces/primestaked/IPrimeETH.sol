// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import "../IERC20Metadata.sol";

interface IPrimeETH is IERC20Metadata {
    function mint(address account, uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;

    function pause() external;

    function unpause() external;

    function updateLRTConfig(address _lrtConfig) external;
}
