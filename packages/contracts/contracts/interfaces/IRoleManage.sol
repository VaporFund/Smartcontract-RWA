// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

interface IRoleManage {
    function setRoleSuperAdmin(address _newRoleSuperAdmin) external;

    function setRole(bytes32 _role) external;

    function revokeRole(bytes32 _role) external;

    function setRoleAddress(bytes32 _role, address _user) external;

    function revokeRoleAddress(bytes32 _role, address _user) external;

    function isValidate(bytes32 _role, address _address) external view returns (bool);

    function isSupperAdmin(address _address) external view returns (bool);

    function isOwner(address _owner) external view returns (bool);
}
