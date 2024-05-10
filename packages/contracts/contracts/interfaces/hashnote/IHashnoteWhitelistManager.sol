// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IHashnoteWhitelistManager {
    /*///////////////////////////////////////////////////////////////
                            Constants
    //////////////////////////////////////////////////////////////*/

    function CLIENT_DOMESTIC_FEEDER() external view returns (bytes32);

    function CLIENT_INTERNATIONAL_FEEDER() external view returns (bytes32);

    function CLIENT_DOMESTIC_SDYF() external view returns (bytes32);

    function CLIENT_INTERNATIONAL_SDYF() external view returns (bytes32);

    function LP_ROLE() external view returns (bytes32);

    function VAULT_ROLE() external view returns (bytes32);

    function OTC_ROLE() external view returns (bytes32);

    function SYSTEM_ROLE() external view returns (bytes32);

    /*///////////////////////////////////////////////////////////////
                            State Variables V1
    //////////////////////////////////////////////////////////////*/

    function sanctionsOracle() external view returns (address);

    /*///////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /*///////////////////////////////////////////////////////////////
                            External Functions
    //////////////////////////////////////////////////////////////*/

    function setSanctionsOracle(address _sanctionsOracle) external;

    function isClient(address _address) external view returns (bool);

    function isClientFeeder(address _address) external view returns (bool);

    function isClientDomesticFeeder(address _address) external view returns (bool);

    function isClientInternationalFeeder(address _address) external view returns (bool);

    function isClientSDYF(address _address) external view returns (bool);

    function isClientDomesticSDYF(address _address) external view returns (bool);

    function isClientInternationalSDYF(address _address) external view returns (bool);

    function isLP(address _address) external view returns (bool);

    function isSystemOrVault(address _address) external view returns (bool);

    function isVault(address _address) external view returns (bool);

    function isOTC(address _address) external view returns (bool);

    function isSystem(address _address) external view returns (bool);

    function isAllowed(address _address) external view returns (bool);

    function hasTokenPrivileges(address _address) external view returns (bool);

    function canUSYC(address _address) external view returns (bool);

    function grantRole(bytes32 _role, address _address) external;

    function grantRoleBatch(bytes32[] calldata _roles, address[] calldata _addresses) external;

    function revokeRole(bytes32 _role, address _address) external;

    function revokeRoleBatch(bytes32[] calldata _roles, address[] calldata _addresses) external;

    function hasRoleAndNotSanctioned(bytes32 _role, address _address) external view returns (bool);

    function hasRoleAndNotSanctionedBatch(bytes32[] calldata _roles, address _address) external view returns (bool);

    function hasRole(bytes32 _role, address _address) external view returns (bool);

    function hasRoleBatch(bytes32[] calldata _roles, address _address) external view returns (bool);

    function pause() external;

    function unpause() external;
}
