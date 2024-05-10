// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IOracle {
    function setDescription(string memory _description) external;

    function getRoundData(uint80 _roundId) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function getRoundDetails(uint80 _roundId) external view returns (uint80 roundId, uint256 balance, uint256 interest, uint256 totalSupply, uint256 updatedAt);

    function latestRoundDetails() external view returns (uint80 roundId, uint256 balance, uint256 interest, uint256 totalSupply, uint256 updatedAt);

    function reportBalance(uint256 _principal, uint256 _interest, uint256 _totalSupply, int256 _nextPrice) external returns (uint80 roundId);
}
