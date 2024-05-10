// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

interface IHashnoteRolesAuthority {
    function doesUserHaveRole(address user, uint8 role) external view returns (bool);

    function doesRoleHaveCapability(uint8 role, address target, bytes4 functionSig) external view returns (bool);

    function canCall(address user, address target, bytes4 functionSig) external view returns (bool);

    function setPublicCapability(address target, bytes4 functionSig, bool enabled) external;

    function setRoleCapability(uint8 role, address target, bytes4 functionSig, bool enabled) external;

    function setUserRole(address user, uint8 role, bool enabled) external;

    function pause() external;

    function unpause() external;

    function transferOwnership(address newOwner) external;
}
