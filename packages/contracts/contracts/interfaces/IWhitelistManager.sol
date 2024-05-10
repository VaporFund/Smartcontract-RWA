// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWhitelistManager {
    function isInWhitelist(bytes32 _merkleRoot, address _address, bytes32[] memory _proof) external view returns (bool);

    function setRootActiveBySignature(bytes32 _root, bytes memory _signature, uint256 _signatureExpTime) external;
}
