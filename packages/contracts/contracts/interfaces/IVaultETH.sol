// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IForwarder.sol";

interface IVaultETH {
    function getTotalClaimOf(IForwarder.ProtocolsForStaking _protocol) external view returns (uint256);

    function withdraw(address _token, uint256 _amount, address _recipient) external;

    function withdrawAndStake(address _token, uint256 _amount, string calldata _stakingProtocol, address _stakingAddress, bytes calldata _data) external;

    function unstake(address _token, uint256 _amount, string calldata _stakingProtocol, address _stakingAddress, bytes calldata _data) external;

    function approve(address _token, address _stakingAddress) external;
}
