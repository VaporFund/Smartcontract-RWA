// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interfaces/IVaultRwaManager.sol";
import "../interfaces/hashnote/IHashnoteHelper.sol";
import "../interfaces/IVaultRwa.sol";
import "../interfaces/IRoleManage.sol";

contract Trigger {
    bytes32 public constant TRIGGER_CALLER_ROLE = keccak256("TRIGGER_CALLER_ROLE");

    /// @dev vault manager
    IVaultRwaManager public vaultManager;

    /// @dev vault
    IVaultRwa public vaultRwa;

    /// @dev role manage
    IRoleManage public roleManage;

    mapping(PlatformType => uint256) public minimumBuy;
    mapping(PlatformType => uint256) public minimumSell;

    event MinimumBuySet(PlatformType indexed platform, uint256 value);
    event MinimumSellSet(PlatformType indexed platform, uint256 value);
    event Buy(address indexed baseToken, uint256 amountStableToken);
    event Sell(address indexed baseToken, uint256 amountYieldToken);

    constructor(address _vaultManager, address _vaultRwa, address _roleManage) {
        roleManage = IRoleManage(_roleManage);
        vaultManager = IVaultRwaManager(_vaultManager);
        vaultRwa = IVaultRwa(_vaultRwa);
        roleManage = IRoleManage(_roleManage);
    }

    function setMinimumBuy(PlatformType platform, uint256 value) external onlyAdmin {
        minimumBuy[platform] = value;
        emit MinimumBuySet(platform, value);
    }

    function setMinimumSell(PlatformType platform, uint256 value) external onlyAdmin {
        minimumSell[platform] = value;
        emit MinimumSellSet(platform, value);
    }

    function buy(address _baseToken, uint256 _amountStableToken) public onlyCaller {
        IVaultRwaManager.Order memory order = vaultManager.getOrder(_baseToken);

        if (minimumBuy[order.platformType] != 0 && minimumBuy[order.platformType] <= _amountStableToken) {
            revert("amount stable must greater minimum buy amount");
        }
        emit Buy(_baseToken, _amountStableToken);

        if (order.platformType == PlatformType.HASHNOTE) {
            IHashnoteHelper hashnoteHelper = IHashnoteHelper(order.platformHelper);
            address teller = hashnoteHelper.teller();

            bytes memory dataBuyFor = hashnoteHelper.encodeCallBuyFor(_amountStableToken, address(vaultRwa));
            vaultRwa.call(teller, dataBuyFor);
        }
    }

    function sell(address _baseToken, uint256 _amountYieldToken) public onlyCaller {
        IVaultRwaManager.Order memory order = vaultManager.getOrder(_baseToken);

        if (minimumSell[order.platformType] != 0 && minimumSell[order.platformType] <= _amountYieldToken) {
            revert("amount stable must greater minimum sell amount");
        }
        emit Sell(_baseToken, _amountYieldToken);

        if (order.platformType == PlatformType.HASHNOTE) {
            IHashnoteHelper hashnoteHelper = IHashnoteHelper(order.platformHelper);
            address teller = hashnoteHelper.teller();

            bytes memory dataSellFor = hashnoteHelper.encodeCallSellFor(_amountYieldToken, address(vaultRwa));
            vaultRwa.call(teller, dataSellFor);
        }
    }

    modifier onlyCaller() {
        require(roleManage.isValidate(TRIGGER_CALLER_ROLE, msg.sender), "Vault: Only caller");
        _;
    }

    modifier onlyAdmin() {
        require(roleManage.isSupperAdmin(msg.sender), "Vault: Only supper admin");
        _;
    }
}
