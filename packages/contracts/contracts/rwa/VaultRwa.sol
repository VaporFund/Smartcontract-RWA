// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";

import "../interfaces/IRoleManage.sol";
import "../interfaces/IVaultRwa.sol";
import "../interfaces/IYieldBearingToken.sol";
import "../interfaces/IWithdrawRequestNFT.sol";
import "../interfaces/IWhitelistManager.sol";
import "../interfaces/IVaultRwaManager.sol";
import "../interfaces/hashnote/IHashnoteHelper.sol";
import "../interfaces/uniswap/ISwapRouter02.sol";
import "../WithdrawRequestNFT.sol";

/*
 * @title Vault
 * @dev This contract represents a vault for staking assets, facilitating the exchange of staked tokens for base tokens and bridging to staking for rewards.
 */

contract VaultRwa is
    Initializable,
    ReentrancyGuardUpgradeable,
    IERC721ReceiverUpgradeable,
    ERC721HolderUpgradeable,
    IVaultRwa
{
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 public constant BASIC_POINT = 10 ** 10;
    bytes32 public constant VAULT_RWA_OPERATOR_ROLE = keccak256("VAULT_RWA_OPERATOR_ROLE");
    bytes32 public constant VAULT_RWA_CALLER_ROLE = keccak256("VAULT_RWA_CALLER_ROLE");
    bytes32 public constant VAULT_RWA_SPENDER_APPROVE_ROLE = keccak256("VAULT_RWA_SPENDER_APPROVE_ROLE");
    address public constant WETH_TOKEN_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    mapping(address => uint256) public pendingValueWithdraw;
    // //TODO: remove in product
    // struct RebaseHistory {
    //     uint256 rebaseAt;
    //     uint256 amount;
    // }
    // mapping(address => RebaseHistory[]) public rebaseHistorys;

    /// @dev The chain id of the contract
    uint256 public chainId;

    /// @dev All requests require multi-signing from the roleManage
    IRoleManage public roleManage;

    /// @dev NFT for requesting withdrawal
    IWithdrawRequestNFT public withdrawNft;

    /// @dev Whitelist
    IWhitelistManager public whitelistManager;

    /// @dev vault manager
    IVaultRwaManager public vaultManager;

    /// @dev uniswap router
    ISwapRouter02 public router;

    /// @dev tracking withdrawal requests
    mapping(uint256 => WithdrawRequest) public requests;

    event Deposit(address indexed baseToken, address pairToken, uint256 inputAmount, uint256 outputAmount);
    event RequestWithdraw(
        uint256 indexed nftId,
        address baseToken,
        uint256 fromAmount,
        address pairToken,
        uint256 toAmount,
        address indexed sender
    );
    event ApprovedRequestWithdraw(uint256 indexed nftId);
    event Withdrawn(uint256 indexed nftId, address indexed sender);

    function initialize(
        uint256 _chainId,
        address _roleManage,
        address _whitelistManager,
        address _vaultManager,
        address _uniswapRouter
    ) external initializer {
        __ReentrancyGuard_init();
        __ERC721Holder_init();

        chainId = _chainId;
        roleManage = IRoleManage(_roleManage);
        whitelistManager = IWhitelistManager(_whitelistManager);
        vaultManager = IVaultRwaManager(_vaultManager);
        router = ISwapRouter02(_uniswapRouter);

        WithdrawRequestNFT nftAddress = new WithdrawRequestNFT(address(this));
        withdrawNft = IWithdrawRequestNFT(address(nftAddress));
    }

    /// @notice set vault manager
    function setVaultManager(address _vaultManager) public onlyAdmin {
        require(_vaultManager != address(0), "Vault: Invalid vault manager address");
        vaultManager = IVaultRwaManager(_vaultManager);
    }

    /// @notice set whitelist manager
    function setWhitelistManager(address _newWhitelistManager) external onlyAdmin {
        require(_newWhitelistManager != address(0), "Vault: Invalid whitelist manager address");
        whitelistManager = IWhitelistManager(_newWhitelistManager);
    }

    /// @notice swap
    function uniswapTrade(
        TokenPath[] memory path,
        address targetToken,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) internal returns (uint256 outputAmount) {
        // Transfer tokens to this contract if from token is not the native token
        address fromToken = path[0].tokenAddress;
        if (WETH_TOKEN_ADDRESS != fromToken) {
            IERC20Upgradeable(fromToken).safeTransferFrom(msg.sender, address(this), amountIn);
            IERC20Upgradeable(fromToken).approve(address(router), amountIn);
        } else {
            amountIn = msg.value;
        }

        bytes memory pathElement;
        for (uint256 i = 0; i < path.length; i++) {
            pathElement = abi.encodePacked(pathElement, path[i].tokenAddress, uint24(path[i].poolFee)); // use encodePacked, because path fee less than 32 bytes
        }
        // Set parameters for Uniswap swap
        ISwapRouter02.ExactInputParams memory params = ISwapRouter02.ExactInputParams({
            path: abi.encodePacked(pathElement, targetToken),
            recipient: address(this),
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum
        });

        // Execute Uniswap trade
        outputAmount = router.exactInput{value: msg.value}(params);

        return outputAmount;
    }

    /// @notice buy base tokens with given pair tokens
    function deposit(
        bytes32 _merkleRoot, // root of markle tree
        bytes32[] memory _proof, // proof for whitelist
        address _baseToken, // base token
        TokenPath[] memory path, // path to swap
        uint256 _depositAmount, // input deposit
        uint256 _outMinimumAmount, // output after swap
        bytes memory _signature, // for whitelist
        uint256 _signatureExpTime // for whitelist
    ) external payable whenNotPaused nonReentrant returns (uint256) {
        if (!whitelistManager.isInWhitelist(_merkleRoot, msg.sender, _proof)) {
            // check if user not whitelist, get current signature and whitelist
            whitelistManager.setRootActiveBySignature(_merkleRoot, _signature, _signatureExpTime);
        }
        IVaultRwaManager.Order memory order = vaultManager.getOrder(_baseToken);
        require(order.active && order.enabled, "Vault: Invalid or disabled token");

        address pairToken = order.pairToken;
        uint256 targetAmount = _depositAmount;

        if (path.length > 0) {
            if (path[0].tokenAddress != WETH_TOKEN_ADDRESS && msg.value > 0) {
                revert("Vault: Deposits with erc20 tokens do not require payment");
            }
            targetAmount = uniswapTrade(path, pairToken, _depositAmount, _outMinimumAmount);
        } else {
            IERC20Upgradeable(pairToken).safeTransferFrom(msg.sender, address(this), targetAmount);
        }

        if (order.minimumDeposit > 0 && targetAmount < order.minimumDeposit) {
            // if order.minimumDeposit > 0 it mean order.minimumDeposit is active
            revert("Vault: Exceeds the limit for deposit");
        }

        uint256 limit = vaultManager.limitLpIns(_baseToken);
        // if limit > 0 it mean limit is active
        if (limit > 0 && _totalValueIn(pairToken) >= limit) {
            revert("Vault: Exceeds the limit for LP instance");
        }

        require(type(uint128).max > targetAmount, "Vault: Amount overflowed");
        if (order.redirect) {
            IHashnoteHelper hashnoteHelper = IHashnoteHelper(order.platformHelper);
            bytes memory dataBuyFor = hashnoteHelper.encodeCallBuyFor(targetAmount, address(this));
            (bool success, bytes memory returnData) = hashnoteHelper.teller().call(dataBuyFor);
            if (!success) {
                assembly {
                    revert(add(returnData, 32), mload(returnData))
                }
            }
        }
        uint256 outputAmount = _deposit(
            _baseToken,
            msg.sender,
            targetAmount,
            order.platformType,
            order.platformHelper,
            order.delayBuyDay
        );
        emit Deposit(_baseToken, pairToken, targetAmount, outputAmount);
        return outputAmount;
    }

    /// @notice request a withdrawal and issue an NFT
    function requestWithdraw(address _baseToken, uint256 _shareAmount) external whenNotPaused nonReentrant {
        IVaultRwaManager.Order memory order = vaultManager.getOrder(_baseToken);
        require(order.active, "Vault: Invalid token");
        require(IYieldBearingToken(_baseToken).balanceOf(msg.sender) >= _shareAmount, "Vault: Insufficient balance");

        uint256 feeShare = 0;
        if (order.platformType == PlatformType.HASHNOTE && order.delaySellDay > 0) {
            IHashnoteHelper hashnoteHelper = IHashnoteHelper(order.platformHelper);
            (uint256 feePercent, ) = hashnoteHelper.calculationPercentInterestPerRound();
            feeShare = ((_shareAmount * feePercent) / BASIC_POINT) * order.delaySellDay; //~ 5 / 365 percent per day
        }

        uint256 share = _shareAmount - feeShare; // minus fee first day
        uint256 amount = amountForShare(_baseToken, share);

        require(amount > 0 && amount <= type(uint128).max && share > 0, "Vault: Invalid amount");

        uint256 tokenId = withdrawNft.mint(_baseToken, amount, msg.sender);

        requests[tokenId] = WithdrawRequest({
            baseToken: _baseToken,
            shareOfToken: share,
            amountOfToken: amount,
            approved: false,
            completed: false
        });

        // Burn shares from user
        IYieldBearingToken(_baseToken).burnShares(msg.sender, _shareAmount);

        pendingValueWithdraw[_baseToken] += amount;

        emit RequestWithdraw(tokenId, order.baseToken, _shareAmount, order.pairToken, amount, msg.sender);
    }

    /// @notice approve withdrawal requests
    function approveRequestWithdraw(uint8[] memory tokenIds) external onlyOperator {
        for (uint8 i = 0; i < tokenIds.length; i++) {
            WithdrawRequest memory request = requests[tokenIds[i]];
            IVaultRwaManager.Order memory order = vaultManager.getOrder(request.baseToken);
            require(
                pendingValueWithdraw[request.baseToken] < _totalValueIn(order.pairToken),
                "Vault: Total value in is not enough to withdraw."
            );
            requests[tokenIds[i]].approved = true;
            emit ApprovedRequestWithdraw(tokenIds[i]);
        }
    }

    /// @notice withdraw by burning the approved NFT and transfer token
    function withdraw(
        uint256 _requestId,
        TokenPath[] memory path,
        address _targetToken,
        uint256 _outMinimumAmount
    ) external whenNotPaused nonReentrant {
        WithdrawRequest storage request = requests[_requestId];
        require(request.approved, "Vault: Request is not approved");
        require(!request.completed, "Vault: Already withdrawn");

        IVaultRwaManager.Order memory order = vaultManager.getOrder(request.baseToken);
        address pairToken = order.pairToken;
        if (path.length > 0 && path[0].tokenAddress != pairToken) {
            // ensure from token is pair token
            revert("Vault: From path token not support");
        }

        require(
            request.amountOfToken > 0 && request.amountOfToken <= type(uint128).max && request.shareOfToken > 0,
            "Vault: Invalid amount"
        );
        require(
            IERC20Upgradeable(pairToken).balanceOf(address(this)) >= request.amountOfToken,
            "Vault: Insufficient liquidity"
        );

        // Transfer NFT to this contract
        IERC721Upgradeable(address(withdrawNft)).safeTransferFrom(msg.sender, address(this), _requestId);
        uint256 targetAmount = request.amountOfToken;
        if (path.length > 0) {
            targetAmount = uniswapTrade(path, _targetToken, request.amountOfToken, _outMinimumAmount);
            IERC20Upgradeable(_targetToken).transfer(msg.sender, targetAmount);
        } else {
            IERC20Upgradeable(pairToken).transfer(msg.sender, targetAmount);
        }

        pendingValueWithdraw[request.baseToken] -= request.amountOfToken;
        request.completed = true;

        emit Withdrawn(_requestId, msg.sender);
    }

    /// @notice a withdrawal target token dont need require approve
    function redirectWithdraw(
        address _baseToken,
        uint256 _shareAmount,
        TokenPath[] memory path,
        address _targetToken,
        uint256 _outMinimumAmount
    ) external whenNotPaused nonReentrant {
        IVaultRwaManager.Order memory order = vaultManager.getOrder(_baseToken);

        require(order.active, "Vault: Invalid token");
        require(order.redirect, "Vault: Require order redirect");
        require(IYieldBearingToken(_baseToken).balanceOf(msg.sender) >= _shareAmount, "Vault: Insufficient balance");

        address pairToken = order.pairToken;
        if (path.length > 0 && path[0].tokenAddress != pairToken) {
            // ensure from token is pair token
            revert("Vault: From path token does not support");
        }
        uint256 share = _shareAmount;
        uint256 amount = 0;
        if (order.platformType == PlatformType.HASHNOTE) {
            IHashnoteHelper hashnoteHelper = IHashnoteHelper(order.platformHelper);
            uint256 feeShare = 0;
            if (order.delaySellDay > 0) {
                (uint256 feePercent, ) = hashnoteHelper.calculationPercentInterestPerRound();
                feeShare = ((_shareAmount * feePercent) / BASIC_POINT) * order.delaySellDay; //~ 5 / 365 percent per day
                share = _shareAmount - feeShare; // minus fee first day
            }

            amount = amountForShare(_baseToken, share); // get amount after minus fee share

            (uint256 amountYieldToken, , ) = hashnoteHelper.buyPreview(amount); // stable coin to yield coin

            (bool success, bytes memory bytesData) = hashnoteHelper.teller().call(
                hashnoteHelper.encodeCallSellFor(amountYieldToken, address(this))
            );
            if (!success) {
                assembly {
                    revert(add(bytesData, 32), mload(bytesData))
                }
            }
            assembly {
                amount := mload(add(bytesData, 0x20)) //update actual amount
            }
        } else {
            revert("Vault: Platform does not support");
        }
        require(amount > 0 && amount <= type(uint128).max && share > 0, "Vault: Invalid amount");
        require(IERC20Upgradeable(pairToken).balanceOf(address(this)) >= amount, "Vault: Insufficient liquidity");
        uint256 tokenId = withdrawNft.mint(_baseToken, amount, address(this));
        requests[tokenId] = WithdrawRequest({
            baseToken: _baseToken,
            shareOfToken: share,
            amountOfToken: amount,
            approved: true,
            completed: true
        });

        uint256 amountTransfer = requests[tokenId].amountOfToken;

        // Burn shares from user
        IYieldBearingToken(_baseToken).burnShares(msg.sender, _shareAmount);

        if (path.length > 0) {
            amountTransfer = uniswapTrade(path, _targetToken, amountTransfer, _outMinimumAmount); //swap and update
            IERC20Upgradeable(_targetToken).transfer(msg.sender, amountTransfer);
        } else {
            IERC20Upgradeable(pairToken).transfer(msg.sender, amountTransfer);
        }

        emit RequestWithdraw(tokenId, order.baseToken, _shareAmount, order.pairToken, amount, msg.sender);
        emit ApprovedRequestWithdraw(tokenId);
        emit Withdrawn(tokenId, msg.sender);
    }

    /// @notice calculate the value of a share
    function amountForShare(address _baseToken, uint256 _share) public view returns (uint256) {
        uint256 totalShares = IYieldBearingToken(_baseToken).totalShares();
        if (totalShares == 0) {
            return 0;
        }
        return (_share * getTotalPooledEther(_baseToken)) / totalShares;
    }

    /// @notice calculate the total value of assets claimed by a user
    function getTotalEtherClaimOf(address _baseToken, address _user) public view returns (uint256) {
        uint256 staked;
        uint256 totalShares = IYieldBearingToken(_baseToken).totalShares();
        uint256 userShare = IYieldBearingToken(_baseToken).shares(_user);
        uint256 totalPooled = getTotalPooledEther(_baseToken);
        if (totalShares > 0) {
            staked = (totalPooled * userShare) / totalShares;
        }
        return staked;
    }

    /// @notice total value of assets in the pool
    function getTotalPooledEther(address _baseToken) public view returns (uint256) {
        IVaultRwaManager.Order memory order = vaultManager.getOrder(_baseToken);
        if (order.platformType == PlatformType.HASHNOTE) {
            IHashnoteHelper hashnoteHelper = IHashnoteHelper(order.platformHelper);
            uint256 totalSTokenInLp = _totalValueIn(order.pairToken);
            uint256 totalSTokenOutLp = hashnoteHelper.getTotalStableTokenByYieldToken(address(this));
            return totalSTokenInLp + totalSTokenOutLp - pendingValueWithdraw[_baseToken];
        }
        revert("Vault: Platform does not support");
    }

    /// @notice the number of shares for a given amount
    function sharesForAmount(address _baseToken, uint256 _amount) public view returns (uint256) {
        uint256 totalPooledEther = getTotalPooledEther(_baseToken);
        if (totalPooledEther == 0) {
            return 0;
        }
        uint256 totalShare = IYieldBearingToken(_baseToken).totalShares();
        return (_amount * totalShare) / totalPooledEther;
    }

    /****************************************
     *          INTERNAL FUNCTIONS          *
     ****************************************/
    function _sharesForDepositAmount(address _baseToken, uint256 _depositAmount) internal view returns (uint256) {
        uint256 totalPooledEther = getTotalPooledEther(_baseToken) - _depositAmount;
        if (totalPooledEther == 0) {
            return _depositAmount;
        }
        uint256 totalShare = IYieldBearingToken(_baseToken).totalShares();
        return (_depositAmount * totalShare) / totalPooledEther;
    }

    function _deposit(
        address _baseToken,
        address _recipient,
        uint256 _amount,
        PlatformType _platformType,
        address _platformHelper,
        uint8 _delayBuyDay
    ) internal returns (uint256) {
        uint256 share = _sharesForDepositAmount(_baseToken, _amount);
        uint256 feeShare = 0;
        if (_platformType == PlatformType.HASHNOTE && _delayBuyDay > 0) {
            IHashnoteHelper hashnoteHelper = IHashnoteHelper(_platformHelper);
            (uint256 feePercent, ) = hashnoteHelper.calculationPercentInterestPerRound();
            feeShare = ((share * feePercent) / BASIC_POINT) * _delayBuyDay; //~ 5 / 365 percent per day
        }

        share -= feeShare; // minus fee first day
        require(_amount <= type(uint128).max && _amount > 0 && share > 0, "Vault: InvalidAmount");

        IYieldBearingToken(_baseToken).mintShares(_recipient, share);
        return share;
    }

    function _requireNotPaused() internal view virtual {
        require(!vaultManager.paused(), "Vault: Pausable: paused");
    }

    function call(address _contract, bytes memory _data) public onlyCaller {
        (bool success, bytes memory returnData) = _contract.call(_data);
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
    }

    function approve(address _contract, address _spender, uint256 _amount) public onlyAdmin {
        require(roleManage.isValidate(VAULT_RWA_SPENDER_APPROVE_ROLE, _spender), "Vault: Spender not permission");
        bytes memory dataApprove = abi.encodeWithSelector(
            bytes4(keccak256("approve(address,uint256)")),
            _spender,
            _amount
        );
        (bool success, ) = _contract.call(dataApprove);
        require(success, "Vault: Approve failed");
    }

    function _totalValueIn(address _pairToken) internal view returns (uint256) {
        return IERC20Upgradeable(_pairToken).balanceOf(address(this));
    }

    /****************************************
     *          MODIFIER FUNCTIONS          *
     ****************************************/

    modifier onlyOperator() {
        require(roleManage.isValidate(VAULT_RWA_OPERATOR_ROLE, msg.sender), "Vault: Only operator");
        _;
    }
    modifier onlyCaller() {
        require(roleManage.isValidate(VAULT_RWA_CALLER_ROLE, msg.sender), "Vault: Only caller");
        _;
    }

    modifier onlyAdmin() {
        require(roleManage.isSupperAdmin(msg.sender), "Vault: Only supper admin");
        _;
    }

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }
}
