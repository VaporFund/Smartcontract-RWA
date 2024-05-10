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

import "../interfaces/IMultiSigController.sol";
import "../interfaces/IVaultStakingBSC.sol";
import "../interfaces/IElasticToken.sol";
import "../interfaces/IWithdrawRequestNFT.sol";
import "../interfaces/IWhitelistManager.sol";
import "../interfaces/IVaultManager.sol";
import "../WithdrawRequestNFT.sol";

/*
 * @title Vault
 * @dev This contract represents a vault for staking assets, facilitating the exchange of staked tokens for base tokens and bridging to staking for rewards.
 */

contract VaultStakingBSC is
    Initializable,
    ReentrancyGuardUpgradeable,
    IERC721ReceiverUpgradeable,
    ERC721HolderUpgradeable,
    IVaultStakingBSC
{
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    mapping(address => uint256) public totalValueOutOfLp;
    mapping(address => uint256) public totalValueInLp;
    mapping(address => uint256) public pendingValueWithdraw;
    mapping(address => RebaseHistory[]) public rebaseHistorys;

    /// @dev The chain id of the contract
    uint256 public chainId;

    /// @dev All requests require multi-signing from the controller
    IMultiSigController public controller;

    /// @dev NFT for requesting withdrawal
    IWithdrawRequestNFT public withdrawNft;

    /// @dev Whitelist
    IWhitelistManager public whitelistManager;

    /// @dev vault manager
    IVaultManager public vaultManager;

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
    event Rebase(
        address operator,
        address baseToken,
        uint256 totalEthLocked,
        uint256 totalVPEEthShares,
        uint256 accruedRewards
    );
    event Withdraw(address indexed tokenAddress, uint amount, uint balance);
    event SwapInLpToOutLp(
        address sender,
        address baseToken,
        address pairToken,
        uint256 amount,
        address recipient,
        uint256 currentRequestId
    );
    event SwapOutLpToInLp(address operator, address baseToken, address pairToken, uint256 amount, address beneficiary);

    function initialize(
        uint256 _chainId,
        address _controller,
        address _whitelistManager,
        address _vaultManager
    ) external initializer {
        __ReentrancyGuard_init();
        __ERC721Holder_init();

        chainId = _chainId;
        controller = IMultiSigController(_controller);
        whitelistManager = IWhitelistManager(_whitelistManager);
        vaultManager = IVaultManager(_vaultManager);

        WithdrawRequestNFT nftAddress = new WithdrawRequestNFT(address(this));
        withdrawNft = IWithdrawRequestNFT(address(nftAddress));
    }

    /// @notice set vault manager
    function setVaultManager(address _vaultManager) public onlyAdmin {
        require(_vaultManager != address(0), "Vault: Invalid vault manager address");
        vaultManager = IVaultManager(_vaultManager);
    }

    /// @notice set whitelist manager
    function setWhitelistManager(address _newWhitelistManager) external onlyAdmin {
        require(_newWhitelistManager != address(0), "Vault: Invalid whitelist manager address");
        whitelistManager = IWhitelistManager(_newWhitelistManager);
    }

    /// @notice buy base tokens with given pair tokens
    function deposit(
        bytes32 _merkleRoot,
        bytes32[] memory _proof,
        address _baseToken,
        uint256 _depositAmount
    ) external whenNotPaused nonReentrant returns (uint256) {
        require(_isWhitelisted(_merkleRoot, msg.sender, _proof), "Vault: Invalid User");

        uint256 limit = vaultManager.limitLpIns(_baseToken);
        if (limit > 0 && totalValueInLp[_baseToken] >= limit) {
            revert("Vault: Exceeds the limit for LP instance");
        }
        IVaultManager.Order memory order = vaultManager.getOrder(_baseToken);
        require(order.active && order.enabled, "Vault: Invalid or disabled token");

        require(type(uint128).max > _depositAmount, "Vault: Amount overflowed");

        address pairToken = order.pairToken;
        IERC20Upgradeable(pairToken).safeTransferFrom(msg.sender, address(this), _depositAmount);
        emit Deposit(_baseToken, pairToken, _depositAmount, _depositAmount);
        return _deposit(_baseToken, msg.sender, _depositAmount);
    }

    /// @notice request a withdrawal and issue an NFT
    function requestWithdraw(address _baseToken, uint256 _baseAmount) external whenNotPaused nonReentrant {
        IVaultManager.Order memory order = vaultManager.getOrder(_baseToken);
        require(order.active, "Vault: Invalid token");
        require(IElasticToken(_baseToken).balanceOf(msg.sender) >= _baseAmount, "Vault: Insufficient balance");

        uint256 share = sharesForAmount(_baseToken, _baseAmount);
        require(_baseAmount > 0 && _baseAmount <= type(uint128).max && share > 0, "Vault: Invalid amount");

        uint256 tokenId = withdrawNft.mint(_baseToken, _baseAmount, msg.sender);

        requests[tokenId] = WithdrawRequest({
            baseToken: _baseToken,
            shareOfToken: share,
            amountOfToken: _baseAmount,
            approved: false,
            completed: false
        });

        // Burn shares from user
        IElasticToken(_baseToken).burnShares(msg.sender, share);

        pendingValueWithdraw[_baseToken] += _baseAmount;

        emit RequestWithdraw(tokenId, order.baseToken, _baseAmount, order.pairToken, _baseAmount, msg.sender);
    }

    /// @notice approve withdrawal requests
    function approveRequestWithdraw(uint8[] memory tokenIds) external onlyOperator {
        for (uint8 i = 0; i < tokenIds.length; i++) {
            WithdrawRequest memory request = requests[tokenIds[i]];
            require(
                pendingValueWithdraw[request.baseToken] < totalValueInLp[request.baseToken],
                "Vault: Total value in is not enough to withdraw."
            );
            requests[tokenIds[i]].approved = true;
            emit ApprovedRequestWithdraw(tokenIds[i]);
        }
    }

    /// @notice withdraw by burning the approved NFT and burn base token
    function withdraw(uint256 _requestId) external whenNotPaused nonReentrant {
        WithdrawRequest storage request = requests[_requestId];
        require(request.approved, "Vault: Request is not approved");
        require(!request.completed, "Vault: Already withdrawn");

        IVaultManager.Order memory order = vaultManager.getOrder(request.baseToken);
        address pairToken = order.pairToken;

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

        //  Transfer pair token to user
        IERC20Upgradeable(pairToken).transfer(msg.sender, request.amountOfToken);

        totalValueInLp[request.baseToken] -= request.amountOfToken;
        pendingValueWithdraw[request.baseToken] -= request.amountOfToken;

        request.completed = true;

        emit Withdrawn(_requestId, msg.sender);
    }

    /// @notice swap LP from the out contract to the in contract
    function swapOutLpToInLp(address _baseToken, uint256 _amount) external onlyOperator {
        address pairToken = vaultManager.getOrder(_baseToken).pairToken;
        require(pairToken != address(0), "Vault: Pair token must not be zero address");
        totalValueInLp[_baseToken] += _amount;
        totalValueOutOfLp[_baseToken] -= _amount;
        IERC20Upgradeable(pairToken).safeTransferFrom(msg.sender, address(this), _amount);
        emit SwapOutLpToInLp(msg.sender, _baseToken, pairToken, _amount, address(this));
    }

    /// @notice swap LP from the in contract to the out contract
    function requestSwapInLpToOutLp(address _baseToken, uint256 _amount, address _recipient) external onlyOperator {
        IVaultManager.Order memory order = vaultManager.getOrder(_baseToken);
        require(IERC20Upgradeable(order.pairToken).balanceOf(address(this)) >= _amount, "Vault: Insufficient funds");

        // Encode the function call for withdrawing from the pair token
        bytes memory data = abi.encodeWithSignature(
            "withdraw(address,address,uint256,address)",
            order.baseToken,
            order.pairToken,
            _amount,
            _recipient
        );

        // Submit the request to the controller
        uint32 currentRequestId = controller.submitRequest(address(this), data);

        emit SwapInLpToOutLp(msg.sender, _baseToken, order.pairToken, _amount, _recipient, currentRequestId);
    }

    /// @notice rebase the accrued rewards
    function rebase(address _baseToken, uint256 _accruedRewards) external onlyOperator {
        totalValueOutOfLp[_baseToken] += _accruedRewards;
        uint256 limitRebaseEstimate = _estimateRebase(_baseToken);
        require(
            _accruedRewards < limitRebaseEstimate,
            "Vault: Accrued rewards must be less than limit rebase estimate"
        );

        rebaseHistorys[_baseToken].push(RebaseHistory({rebaseAt: block.timestamp, amount: _accruedRewards}));
        emit Rebase(
            msg.sender,
            _baseToken,
            getTotalPooledEther(_baseToken),
            IElasticToken(_baseToken).totalShares(),
            _accruedRewards
        );
    }

    /// @notice calculate the value of a share
    function amountForShare(address _baseToken, uint256 _share) public view returns (uint256) {
        uint256 totalShares = IElasticToken(_baseToken).totalShares();
        if (totalShares == 0) {
            return 0;
        }
        return (_share * getTotalPooledEther(_baseToken)) / totalShares;
    }

    /// @notice calculate the total value of assets claimed by a user
    function getTotalEtherClaimOf(address _baseToken, address _user) public view returns (uint256) {
        uint256 staked;
        uint256 totalShares = IElasticToken(_baseToken).totalShares();
        uint256 userShare = IElasticToken(_baseToken).shares(_user);
        uint256 totalPooled = getTotalPooledEther(_baseToken);
        if (totalShares > 0) {
            staked = (totalPooled * userShare) / totalShares;
        }
        return staked;
    }

    /// @notice total value of assets in the pool
    function getTotalPooledEther(address _baseToken) public view returns (uint256) {
        return totalValueOutOfLp[_baseToken] + totalValueInLp[_baseToken] - pendingValueWithdraw[_baseToken];
    }

    /// @notice the number of shares for a given amount
    function sharesForAmount(address _baseToken, uint256 _amount) public view returns (uint256) {
        uint256 totalPooledEther = getTotalPooledEther(_baseToken);
        if (totalPooledEther == 0) {
            return 0;
        }
        uint256 totalShare = IElasticToken(_baseToken).totalShares();
        return (_amount * totalShare) / totalPooledEther;
    }

    /// @notice perform withdrawal
    function withdraw(
        address _baseToken,
        address _pairToken,
        uint256 _amount,
        address _recipient
    ) external onlyController {
        totalValueOutOfLp[_baseToken] += _amount;
        totalValueInLp[_baseToken] -= _amount;
        IERC20Upgradeable(_pairToken).safeTransfer(_recipient, _amount);
        emit Withdraw(_pairToken, _amount, IERC20Upgradeable(_pairToken).balanceOf(address(this)));
    }

    /****************************************
     *          INTERNAL FUNCTIONS          *
     ****************************************/
    function _sharesForDepositAmount(address _baseToken, uint256 _depositAmount) internal view returns (uint256) {
        uint256 totalPooledEther = getTotalPooledEther(_baseToken) - _depositAmount;
        if (totalPooledEther == 0) {
            return _depositAmount;
        }
        uint256 totalShare = IElasticToken(_baseToken).totalShares();
        return (_depositAmount * totalShare) / totalPooledEther;
    }

    function _deposit(address _baseToken, address _recipient, uint256 _amount) internal returns (uint256) {
        totalValueInLp[_baseToken] += _amount;
        uint256 share = _sharesForDepositAmount(_baseToken, _amount);
        require(_amount <= type(uint128).max && _amount != 0 && share != 0, "Vault: InvalidAmount");

        IElasticToken(_baseToken).mintShares(_recipient, share);
        return share;
    }

    function _isWhitelisted(
        bytes32 _merkleRoot,
        address _address,
        bytes32[] memory _proof
    ) internal view returns (bool) {
        return whitelistManager.isInWhitelist(_merkleRoot, _address, _proof);
    }

    function _requireNotPaused() internal view virtual {
        require(!vaultManager.paused(), "Vault: Pausable: paused");
    }

    function _estimateRebase(address _baseToken) internal view virtual returns (uint256) {
        uint256 maxRebasePercentPerHour = vaultManager.maxRebasePercentPerHour(_baseToken);

        if (rebaseHistorys[_baseToken].length < 1 || maxRebasePercentPerHour == 0) {
            return type(uint256).max;
        }

        RebaseHistory memory lastRebase = rebaseHistorys[_baseToken][rebaseHistorys[_baseToken].length - 1];
        uint256 rangeLastRebaseHour = (block.timestamp - lastRebase.rebaseAt) / 1 hours;
        require(rangeLastRebaseHour > 1, "Vault: Rebase mint after 1 hour");

        uint256 limitRebaseEstimate = ((maxRebasePercentPerHour * totalValueOutOfLp[_baseToken]) /
            vaultManager.BASIC_POINT()) * rangeLastRebaseHour;

        return limitRebaseEstimate;
    }

    /****************************************
     *          MODIFIER FUNCTIONS          *
     ****************************************/

    modifier onlyController() {
        require(msg.sender == address(controller), "Vault: Only controller");
        _;
    }

    modifier onlyOperator() {
        require(controller.isOperator(msg.sender), "Vault: Only operator");
        _;
    }

    modifier onlyAdmin() {
        require(controller.isAdmin(msg.sender), "Vault: Only admin");
        _;
    }

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }
}
