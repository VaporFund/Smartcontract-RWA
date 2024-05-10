// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IVaultRwa {
    struct WithdrawRequest {
        address baseToken;
        uint256 shareOfToken;
        uint256 amountOfToken;
        bool approved;
        bool completed;
    }

    struct TokenPath {
        address tokenAddress;
        uint24 poolFee;
    }

    function amountForShare(address _baseToken, uint256 _share) external view returns (uint256);

    function sharesForAmount(address _baseToken, uint256 _amount) external view returns (uint256);

    function getTotalPooledEther(address _baseToken) external view returns (uint256);

    function getTotalEtherClaimOf(address _baseToken, address _user) external view returns (uint256);

    function call(address _contract, bytes memory _data) external;
}
