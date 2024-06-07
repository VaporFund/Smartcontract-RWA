// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../interfaces/IRoleManage.sol";
import "../interfaces/IVaultRwa.sol";
import "../interfaces/IYieldBearingToken.sol";
import "../interfaces/ITokenFactory.sol";
import "../interfaces/IVaultRwaManager.sol";

contract VaultRwaManager is Initializable {
    using AddressUpgradeable for address;

    uint256 constant BASIC_POINT = 10 ** 10;
    bytes32 public constant VAULT_RWA_OPERATOR_ROLE = keccak256("VAULT_RWA_OPERATOR_ROLE");

    struct Order {
        address baseToken;
        address pairToken;
        uint256 minimumDeposit;
        uint8 delayBuyDay;
        uint8 delaySellDay;
        address beneficialAddress;
        PlatformType platformType;
        address platformHelper;
        bool active;
        bool enabled;
        bool redirect;
    }

    bool public paused;
    IRoleManage public roleManage;
    ITokenFactory public factory;
    IVaultRwa public vault;
    address[] public bridgeTokens;
    mapping(address => Order) public orders;
    mapping(address => uint256) public limitLpIns;

    event OrderCreated(address indexed baseToken, address pairToken, address beneficialAddress);
    event OrderUpdated(address indexed baseToken, address pairToken, address beneficialAddress);
    event Paused(address account);
    event Unpaused(address account);
    event RebasePercentSet(address indexed _address, uint256 _rebasePercent);
    event MinimumDepositSet(address indexed baseToken, uint256 minimumDeposit);
    event FeeDaysSet(address indexed baseToken, uint8 newFeeDepositDay, uint8 newFeeWithdrawDay);
    event RedirectUpdated(bool newValue);

    function initialize(address _roleManage) external initializer {
        roleManage = IRoleManage(_roleManage);
        paused = false;
    }

    function getOrder(address _baseToken) external view returns (Order memory) {
        return orders[_baseToken];
    }

    function setupNewOrder(
        address _baseToken,
        address _pairToken,
        PlatformType platformType,
        address platformHelper
    ) external onlyOperator {
        require(!orders[_baseToken].active, "VaultManager: Token is already listed");
        orders[_baseToken] = Order({
            baseToken: _baseToken,
            pairToken: _pairToken,
            minimumDeposit: 0,
            delayBuyDay: 0,
            delaySellDay: 0,
            beneficialAddress: address(vault),
            platformType: platformType,
            platformHelper: platformHelper,
            active: true,
            enabled: true,
            redirect: false
        });

        emit OrderCreated(_baseToken, _pairToken, address(vault));
    }

    function updateOrder(
        address _baseToken,
        address _pairToken,
        PlatformType _platformType,
        address _platformHelper
    ) external onlyAdmin {
        Order storage order = orders[_baseToken];
        order.pairToken = _pairToken;
        order.platformType = _platformType;
        order.platformHelper = _platformHelper;
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

    function setMinimumDeposit(address _baseToken, uint256 minimumDeposit) external onlyOperator {
        orders[_baseToken].minimumDeposit = minimumDeposit;
        emit MinimumDepositSet(_baseToken, minimumDeposit);
    }

    function setFeeDays(address _baseToken, uint8 newFeeDepositDay, uint8 newFeeWithdrawDay) external onlyOperator {
        Order storage order = orders[_baseToken];
        order.delayBuyDay = newFeeDepositDay;
        order.delaySellDay = newFeeWithdrawDay;
        emit FeeDaysSet(_baseToken, newFeeDepositDay, newFeeWithdrawDay);
    }

    function setRedirect(address _baseToken, bool status) external onlyAdmin {
        Order storage order = orders[_baseToken];
        order.redirect = status;
        emit RedirectUpdated(status);
    }

    function createToken(
        string calldata tokenName,
        string calldata tokenSymbol,
        uint8 tokenDecimals
    ) external onlyOperator {
        require(address(factory) != address(0), "Token factory is not set");
        require(address(vault) != address(0), "Vault is not set");
        IYieldBearingToken newToken = factory.createYieldBearingToken(
            tokenName,
            tokenSymbol,
            tokenDecimals,
            address(vault)
        );
        bridgeTokens.push(address(newToken));
    }

    function setTokenFactory(address _factory) external onlyAdmin {
        factory = ITokenFactory(_factory);
    }

    function setLimitForLPIn(address _baseToken, uint256 _amount) external onlyAdmin {
        limitLpIns[_baseToken] = _amount;
    }

    function setVault(address _vault) external onlyAdmin {
        vault = IVaultRwa(_vault);
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
        require(roleManage.isValidate(VAULT_RWA_OPERATOR_ROLE, msg.sender), "Vault: Only operator");
        _;
    }

    modifier onlyAdmin() {
        require(roleManage.isSupperAdmin(msg.sender), "Vault: Only supper admin");
        _;
    }
}
