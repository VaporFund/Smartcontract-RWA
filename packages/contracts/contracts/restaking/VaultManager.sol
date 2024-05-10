// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../interfaces/IMultiSigController.sol";
import "../interfaces/IVaultStakingBSC.sol";
import "../interfaces/IElasticToken.sol";

interface ITokenFactory {
    function createToken(
        string calldata tokenName,
        string calldata tokenSymbol,
        uint8 tokenDecimals,
        address owner
    ) external returns (IElasticToken newToken);
}

contract VaultManager is Initializable {
    using AddressUpgradeable for address;

    struct Order {
        address baseToken;
        address pairToken;
        address beneficialAddress;
        bool active;
        bool enabled;
    }

    uint256 constant BASIC_POINT = 10 ** 10;

    IMultiSigController public controller;
    ITokenFactory public factory;
    IVaultStakingBSC public vault;
    address[] public bridgeTokens;
    mapping(address => Order) public orders;
    mapping(address => uint256) public limitLpIns;
    mapping(address => uint256) public maxRebasePercentPerHour;

    bool public paused;

    event OrderCreated(address indexed baseToken, address pairToken, address beneficialAddress);
    event OrderUpdated(address indexed baseToken, address pairToken, address beneficialAddress);
    event Paused(address account);
    event Unpaused(address account);
    event RebasePercentSet(address indexed _address, uint256 _rebasePercent);

    function initialize(address _controller) external initializer {
        controller = IMultiSigController(_controller);
        paused = false;
    }

    function getOrder(address _baseToken) external view returns (Order memory) {
        return orders[_baseToken];
    }

    function setRebasePercent(address _address, uint256 _rebasePercent) external onlyAdmin {
        require(_address != address(0), "VaultManager: Invalid address");
        require(
            _rebasePercent <= BASIC_POINT,
            "VaultManager: Rebase percent must be less than or equal to BASIC_POINT"
        );

        maxRebasePercentPerHour[_address] = _rebasePercent;
        emit RebasePercentSet(_address, _rebasePercent);
    }

    function setupNewOrder(address _baseToken, address _pairToken) external onlyOperator {
        require(!orders[_baseToken].active, "VaultManager: Token is already listed");
        orders[_baseToken] = Order({
            baseToken: _baseToken,
            pairToken: _pairToken,
            beneficialAddress: address(vault),
            active: true,
            enabled: true
        });

        emit OrderCreated(_baseToken, _pairToken, address(vault));
    }

    function updateOrder(address _baseToken, address _pairToken) external onlyAdmin {
        orders[_baseToken] = Order({
            baseToken: _baseToken,
            pairToken: _pairToken,
            beneficialAddress: address(vault),
            active: true,
            enabled: true
        });

        emit OrderUpdated(_baseToken, _pairToken, address(vault));
    }

    function disableOrder(address _baseToken) external onlyOperator {
        require(orders[_baseToken].active, "VaultManager: Invalid order");
        orders[_baseToken].enabled = false;
    }

    function enableOrder(address _baseToken) external onlyOperator {
        require(orders[_baseToken].active, "VaultManager: Invalid order");
        orders[_baseToken].enabled = true;
    }

    function createToken(
        string calldata tokenName,
        string calldata tokenSymbol,
        uint8 tokenDecimals
    ) external onlyOperator {
        require(address(factory) != address(0), "Token factory is not set");
        require(address(vault) != address(0), "Vault is not set");
        IElasticToken newToken = factory.createToken(tokenName, tokenSymbol, tokenDecimals, address(vault));
        bridgeTokens.push(address(newToken));
    }

    function setTokenFactory(address _factory) external onlyAdmin {
        factory = ITokenFactory(_factory);
    }

    function setLimitForLPIn(address _baseToken, uint256 _amount) external onlyAdmin {
        limitLpIns[_baseToken] = _amount;
    }

    function setVault(address _vault) external onlyAdmin {
        vault = IVaultStakingBSC(_vault);
    }

    function pauseContract() external onlyAdmin {
        paused = true;
        emit Paused(msg.sender);
    }

    function unPauseContract() external onlyAdmin {
        paused = false;
        emit Unpaused(msg.sender);
    }

    modifier onlyOperator() {
        require(controller.isOperator(msg.sender), "VaultManager: Only operator");
        _;
    }

    modifier onlyAdmin() {
        require(controller.isAdmin(msg.sender), "VaultManager: Only admin");
        _;
    }
}
