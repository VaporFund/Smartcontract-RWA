// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BalanceHelper is Ownable {
    uint256 public maxQuery;

    constructor(uint256 _maxQuery) {
        maxQuery = _maxQuery;
    }

    function setMaxQuery(uint256 _maxQuery) external onlyOwner {
        maxQuery = _maxQuery;
    }

    function queryBalances(address _contractAddress, address[] memory _addresses) external view returns (uint256[] memory) {
        require(_addresses.length <= maxQuery, "Length of addresses must be less than or equal to maxQuery");
        uint256[] memory balances = new uint256[](_addresses.length);
        for (uint256 i = 0; i < _addresses.length; i++) {
            balances[i] = IERC20(_contractAddress).balanceOf(_addresses[i]);
        }
        return balances;
    }
}
