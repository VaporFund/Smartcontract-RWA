// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IRoleManage.sol";

contract RoleManage is Ownable, IRoleManage {
    using EnumerableSet for EnumerableSet.AddressSet;

    address public roleSuperAdmin;
    mapping(bytes32 => bool) public rolePermissions;
    mapping(bytes32 => EnumerableSet.AddressSet) roleAddresses;
    bytes32[] public roles;

    event RoleSet(bytes32 indexed role);
    event RoleRevoked(bytes32 indexed role);
    event RoleAddressSet(bytes32 indexed role, address indexed user);
    event RoleAddressRevoked(bytes32 indexed role, address indexed user);
    event RoleSuperAdminUpdated(address indexed newRoleSuperAdmin);

    constructor(address _roleSuperAdmin) {
        roleSuperAdmin = _roleSuperAdmin;
    }

    function setRoleSuperAdmin(address _newRoleSuperAdmin) external onlyOwner {
        roleSuperAdmin = _newRoleSuperAdmin;
        emit RoleSuperAdminUpdated(_newRoleSuperAdmin);
    }

    function setRole(bytes32 _role) external onlySupperAdminOrOwner {
        require(!roleExists(_role), "Role already exists");
        roles.push(_role);
        rolePermissions[_role] = true;
        emit RoleSet(_role);
    }

    function revokeRole(bytes32 _role) public onlySupperAdminOrOwner {
        require(roleExists(_role), "Role does not exist");
        removeRole(_role);
        rolePermissions[_role] = false;
        emit RoleRevoked(_role);
    }

    function setRoleAddress(bytes32 _role, address _user) external onlySupperAdminOrOwner {
        require(roleExists(_role), "Role does not exist");
        require(rolePermissions[_role], "Role is not permitted");
        roleAddresses[_role].add(_user);
        emit RoleAddressSet(_role, _user);
    }

    function revokeRoleAddress(bytes32 _role, address _user) external onlySupperAdminOrOwner {
        require(roleExists(_role), "Role does not exist");
        roleAddresses[_role].remove(_user);
        emit RoleAddressRevoked(_role, _user);
    }

    function isValidate(bytes32 _role, address _address) external view returns (bool) {
        require(roleIsActive(_role), "Role does not exist or active");
        return roleAddresses[_role].contains(_address);
    }

    function isSupperAdmin(address _address) external view returns (bool) {
        return _address == roleSuperAdmin;
    }

    function isOwner(address _address) external view returns (bool) {
        return _address == owner();
    }

    function getAllRoles() public view returns (bytes32[] memory) {
        return roles;
    }

    // -------------------INTERNAL-------------------

    function roleExists(bytes32 _role) internal view returns (bool) {
        for (uint256 i = 0; i < roles.length; i++) {
            if (roles[i] == _role) {
                return true;
            }
        }
        return false;
    }

    function removeRole(bytes32 _role) internal {
        bytes32 lastRole = roles[roles.length - 1];
        for (uint256 i = 0; i < roles.length; i++) {
            if (roles[i] == _role) {
                roles[i] = lastRole;
            }
        }
        roles.pop();
    }

    function roleIsActive(bytes32 _role) internal view returns (bool) {
        return rolePermissions[_role];
    }

    // -------------------MODIFIER-------------------
    modifier onlySupperAdminOrOwner() {
        require(_msgSender() == roleSuperAdmin || _msgSender() == owner(), "only supper admin or owner");
        _;
    }
}
