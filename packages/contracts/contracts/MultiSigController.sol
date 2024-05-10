//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IMultiSigController.sol";

/*
 * @title MultiSigController
 * @dev A controller facilitating multi-signature operations within the system, used for approval and voting on operators.
 */

contract MultiSigController is Initializable, IMultiSigController {
    using AddressUpgradeable for address;

    struct Request {
        address contractAddress;
        bytes data;
        bool executed;
        uint numConfirmations;
    }

    enum RoleAction {
        SET_ADMIN,
        ADD_OPERATOR,
        REMOVE_OPERATOR
    }

    struct RoleRequest {
        RoleAction role;
        address account;
        uint numConfirmations;
        bool executed;
    }

    Request[] public requests;
    RoleRequest[] public roleRequests;

    address[] private operators;
    mapping(address => bool) public isOperator;

    // Contract list
    mapping(address => bool) private contracts;

    uint8 public numConfirmationsRequired;

    address private admin; // this guy can only add and remove operators

    // mapping from request index => owner => bool
    mapping(uint32 => mapping(address => bool)) public isConfirmed;

    // mapping from role request index => owner => bool
    mapping(uint32 => mapping(address => bool)) public isRoleConfirmed;

    event SubmitRequest(uint32 indexed requestId, address indexed contractAddress);
    event ConfirmRequest(uint32 indexed requestId, address indexed contractAddress, address indexed operator);
    event RevokeRequest(uint32 indexed requestId, address indexed contractAddress, address indexed operator);
    event ExecuteRequest(uint32 indexed requestId, address indexed contractAddress, address indexed sender);
    event SubmitRoleRequest(uint32 indexed requestId, uint8 role, address indexed account);
    event ConfirmRoleRequest(uint32 indexed requestId, uint8 role, address account, address indexed operator);
    event RevokeRoleRequest(uint32 indexed requestId, uint8 role, address account, address indexed operator);
    event ExecuteRoleRequest(uint32 indexed requestId, uint8 role, address indexed account);

    function initialize(address _admin, address[] memory _operators, uint8 _numConfirmationsRequired) external initializer {
        require(_operators.length > 0, "MultiSig: Operators required");
        require(_numConfirmationsRequired > 0 && _numConfirmationsRequired <= _operators.length, "MultiSig: Invalid number of required confirmations");
        admin = _admin;
        for (uint8 i = 0; i < _operators.length; i++) {
            address operator = _operators[i];

            require(operator != address(0), "MultiSig: Invalid operator");
            require(!isOperator[operator], "MultiSig: Operator not unique");

            isOperator[operator] = true;
            operators.push(operator);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    /// @notice set number confirm require
    function setNumConfirmationsRequired(uint8 _numConfirmationsRequired) external onlyAdmin {
        require(_numConfirmationsRequired > 0 && _numConfirmationsRequired <= operators.length, "MultiSig: Invalid number of confirmations required");
        numConfirmationsRequired = _numConfirmationsRequired;
    }

    /// @notice submit role request
    function submitRoleRequest(RoleAction role, address _account) external onlyOperator returns (uint256) {
        if (role == RoleAction.SET_ADMIN) {
            require(admin != _account, "MultiSig: Cannot set admin to current admin");
        } else if (role == RoleAction.ADD_OPERATOR) {
            require(!isOperator[_account], "MultiSig: Address is already an operator");
        } else if (role == RoleAction.REMOVE_OPERATOR) {
            require(numConfirmationsRequired <= operators.length - 1, "MultiSig: Number of confirmations must be less than or equal to available operators");
            require(isOperator[_account], "MultiSig: Address is not an operator");
        }
        uint32 requestId = uint32(roleRequests.length);
        roleRequests.push(RoleRequest({role: role, account: _account, executed: false, numConfirmations: 0}));

        emit SubmitRoleRequest(requestId, uint8(role), _account);

        return requestId;
    }

    /// @notice revoke a pending role request from the caller
    function revokeRoleRequest(uint32 _requestId) external onlyOperator {
        RoleRequest storage roleRequest = roleRequests[_requestId];

        require(isRoleConfirmed[_requestId][msg.sender], "MultiSig: Request not confirmed");

        roleRequest.numConfirmations -= 1;
        isRoleConfirmed[_requestId][msg.sender] = false;

        emit RevokeRoleRequest(_requestId, uint8(roleRequest.role), roleRequest.account, msg.sender);
    }

    /// @notice confirm role request
    function confirmRoleRequest(uint32 _requestId) external onlyOperator {
        require(_requestId < roleRequests.length, "MultiSig: ID does not exist");
        require(!roleRequests[_requestId].executed, "MultiSig: ID already executed");
        require(!isRoleConfirmed[_requestId][msg.sender], "MultiSig: ID already confirmed");

        RoleRequest storage roleRequest = roleRequests[_requestId];
        unchecked {
            roleRequest.numConfirmations += 1;
        }

        isRoleConfirmed[_requestId][msg.sender] = true;

        emit ConfirmRoleRequest(_requestId, uint8(roleRequest.role), roleRequest.account, msg.sender);
    }

    /// @notice execute role request
    function executeRoleRequest(uint32 _requestId) external onlyOperator {
        require(_requestId < roleRequests.length, "MultiSig: ID does not exist");
        require(!roleRequests[_requestId].executed, "MultiSig: ID already executed");

        RoleRequest storage roleRequest = roleRequests[_requestId];

        require(roleRequest.numConfirmations >= numConfirmationsRequired, "MultiSig: Threshold is not met");
        roleRequest.executed = true;

        if (roleRequest.role == RoleAction.SET_ADMIN) {
            admin = roleRequest.account;
        } else if (roleRequest.role == RoleAction.ADD_OPERATOR) {
            isOperator[roleRequest.account] = true;
            operators.push(roleRequest.account);
        } else if (roleRequest.role == RoleAction.REMOVE_OPERATOR) {
            uint index;
            for (uint8 i = 0; i < operators.length; i++) {
                if (operators[i] == roleRequest.account) {
                    index = i;
                    break;
                }
            }
            operators[index] = operators[operators.length - 1];
            operators.pop();
            isOperator[roleRequest.account] = false;
        }

        emit ExecuteRoleRequest(_requestId, uint8(roleRequest.role), roleRequest.account);
    }

    /// @notice transfer admin permission to the target address
    function transferAdmin(address _toAddress) external {
        require(msg.sender == admin, "MultiSig: Unauthorized");
        admin = _toAddress;
    }

    /// @notice add supported contract that allows submission of requests
    function addContract(address _contractAddress) external onlyAdmin {
        require(_contractAddress != address(0), "MultiSig: Invalid address");
        require(!contracts[_contractAddress], "MultiSig: Duplicated address");
        contracts[_contractAddress] = true;
    }

    /// @notice remove supported contract
    function removeContract(address _contractAddress) external onlyAdmin {
        require(contracts[_contractAddress], "MultiSig: Invalid address");
        contracts[_contractAddress] = false;
    }

    /// @notice submit a request
    function submitRequest(address _contractAddress, bytes memory _data) external onlyContract returns (uint32) {
        uint32 requestId = uint32(requests.length);

        requests.push(Request({contractAddress: _contractAddress, data: _data, executed: false, numConfirmations: 0}));

        emit SubmitRequest(requestId, _contractAddress);

        return requestId;
    }

    /// @notice operators confirm the pending request
    function confirmRequest(uint32 _requestId) external onlyOperator requestExists(_requestId) notExecuted(_requestId) notConfirmed(_requestId) {
        Request storage request = requests[_requestId];
        unchecked {
            request.numConfirmations += 1;
        }

        isConfirmed[_requestId][msg.sender] = true;

        emit ConfirmRequest(_requestId, request.contractAddress, msg.sender);
    }

    /// @notice execute request's calldata against contract when the request reaches its threshold
    function executeRequest(uint32 _requestId) external onlyOperator requestExists(_requestId) notExecuted(_requestId) {
        Request storage request = requests[_requestId];

        require(request.numConfirmations >= numConfirmationsRequired, "MultiSig: Threshold is not met");

        request.executed = true;

        // TODO: support tx's value
        (bool success, bytes memory returnData) = request.contractAddress.call(request.data);
        if (!success) {
            revert(string(returnData));
        }

        emit ExecuteRequest(_requestId, request.contractAddress, msg.sender);
    }

    /// @notice revoke a pending request from the caller
    function revokeRequest(uint32 _requestId) external onlyOperator {
        Request storage request = requests[_requestId];

        require(isConfirmed[_requestId][msg.sender], "MultiSig: Request not confirmed");

        request.numConfirmations -= 1;
        isConfirmed[_requestId][msg.sender] = false;

        emit RevokeRequest(_requestId, request.contractAddress, msg.sender);
    }

    ///@notice the list of operators
    function getOperators() public view returns (address[] memory) {
        return operators;
    }

    ///@notice the list of requests from the contract
    function getRequest(uint _requestId) public view returns (address contractAddress, bool executed, uint numConfirmations) {
        Request storage request = requests[_requestId];

        return (request.contractAddress, request.executed, request.numConfirmations);
    }

    ///@notice the count of requests
    function getRequestCount() public view returns (uint) {
        return requests.length;
    }

    ///@notice the list of role requests from the contract
    function getRoleRequest(uint _requestId) public view returns (RoleAction role, address account, uint numConfirmations, bool executed) {
        RoleRequest storage roleRequest = roleRequests[_requestId];

        return (roleRequest.role, roleRequest.account, roleRequest.numConfirmations, roleRequest.executed);
    }

    ///@notice the count of role requests
    function getRoleRequestCount() public view returns (uint) {
        return roleRequests.length;
    }

    ///@notice check is admin
    function isAdmin(address _admin) public view returns (bool) {
        return admin == _admin;
    }

    /****************************************
     *          INTERNAL FUNCTIONS          *
     ****************************************/

    modifier onlyOperator() {
        require(isOperator[msg.sender], "MultiSig: Only operator");
        _;
    }

    modifier onlyAdmin() {
        require(admin == msg.sender, "MultiSig: Only admin");
        _;
    }

    modifier onlyContract() {
        require(contracts[msg.sender], "MultiSig: Unauthorized caller");
        _;
    }

    modifier requestExists(uint32 _requestIndex) {
        require(_requestIndex < requests.length, "MultiSig: ID does not exist");
        _;
    }

    modifier notExecuted(uint32 _requestIndex) {
        require(!requests[_requestIndex].executed, "MultiSig: ID already executed");
        _;
    }

    modifier notConfirmed(uint32 _requestIndex) {
        require(!isConfirmed[_requestIndex][msg.sender], "MultiSig: ID already confirmed");
        _;
    }
}
