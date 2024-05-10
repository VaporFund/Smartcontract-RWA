// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

interface IForwarder {
    struct ProtocolInfo {
        address registryAddress;
        address tokenAddress;
        address nftAddress;
    }
    enum ProtocolsForStaking {
        MOCK,
        ETHERFI
    }

    function initialize(address _controller, address _vault) external;

    function getLpStakingAddress(ProtocolsForStaking _protocol) external view returns (address);

    function getTotalClaimOf(ProtocolsForStaking _protocol) external view returns (uint256);

    function requestStake(ProtocolsForStaking _protocol, address _tokenAddress, uint256 _amountIn) external;

    function requestUnstake(ProtocolsForStaking _protocol, address _tokenAddress, uint256 _unstakeAmount) external;

    function register(ProtocolsForStaking _protocol, address _registryAddress, address _tokenAddress, address _nftAddress) external;
}
