// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../WithdrawRequestNFT.sol";
import "../interfaces/IMultiSigController.sol";
import "../interfaces/IVaultStakingETH.sol";
import "../interfaces/IElasticToken.sol";
import "../interfaces/etherfi/IWithdrawRequestNFT.sol";
import "../interfaces/IForwarder.sol";
import "../interfaces/etherfi/IeTH.sol";

import {Constants} from "../utility/Constants.sol";

/*
 * @title Vault
 * @dev a vault contract responsible for locking tokens for any purpose. also acts as the bridge interface between all supported chains.
 */

interface IWithdraw {
    function requestWithdraw(
        address _token,
        uint256 _amount,
        string memory _stakingProtocol,
        address _stakingAddress,
        address _tokenAddress,
        bytes memory _data
    ) external;

    function claimWithdraw(
        string memory _stakingProtocol,
        address _stakingAddress,
        address _tokenAddress,
        address _nftAddress,
        uint256 _nftId,
        bytes memory _data
    ) external;

    function withdraw(address _token, uint256 _amount, address _recipient) external;

    function withdrawAndStake(
        address _token,
        uint256 _amount,
        string memory _stakingProtocol,
        address _stakingAddress,
        bytes memory _data
    ) external;

    function unstake(
        address _token,
        uint256 _amount,
        string memory _stakingProtocol,
        address _stakingAddress,
        bytes memory _data
    ) external;
}

contract VaultStakingETH is
    Initializable,
    ReentrancyGuardUpgradeable,
    IERC721ReceiverUpgradeable,
    ERC721HolderUpgradeable,
    IVaultStakingETH
{
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    /// @dev the chain id of the contract, is passed in to avoid any evm issues
    uint256 public chainId;
    /// @dev requests need to be signed by multiple operators.
    IMultiSigController public controller;
    /// @dev forwarder to restake or withdraw
    IForwarder public forwarder;
    /// @dev list pending request ID when request withdraws
    mapping(address => EnumerableSetUpgradeable.UintSet) pendingClaims;

    event RequestWithdraw(
        address indexed tokenAddress,
        uint amount,
        uint balance,
        string stakingProtocol,
        address stakingAddress
    );
    event ClaimWithdraw(
        uint256 indexed nftId,
        string stakingProtocol,
        address stakingAddress,
        address tokenAddress,
        address nftAddress
    );
    event Deposit(address indexed sender, address indexed tokenAddress, uint amount, uint balance);
    event RequestWithdrawFund(
        address indexed operator,
        address indexed tokenAddress,
        uint amount,
        address recipient,
        uint32 requestId
    );
    event Withdraw(address indexed tokenAddress, uint amount, uint balance);
    event WithdrawAndStake(
        address indexed tokenAddress,
        uint amount,
        uint balance,
        string stakingProtocol,
        address stakingAddress
    );
    event UnstakeAndDeposit(
        address indexed tokenAddress,
        uint amount,
        uint balance,
        string stakingProtocol,
        address stakingAddress
    );

    function initialize(uint256 _chainId, address _controller) external initializer {
        __ReentrancyGuard_init();
        chainId = _chainId;
        controller = IMultiSigController(_controller);
    }

    /// @notice deposit native ETH
    receive() external payable {
        emit Deposit(msg.sender, Constants.ETH_TOKEN, msg.value, address(this).balance);
    }

    /// @notice another way to deposit native ETH
    function depositWithETH() external payable nonReentrant {
        emit Deposit(msg.sender, Constants.ETH_TOKEN, msg.value, address(this).balance);
    }

    /// @notice set forwarder
    function setForwarder(address _forwarder) external onlyAdmin {
        forwarder = IForwarder(_forwarder);
    }

    // @notice get total able claim
    function getTotalClaimOf(IForwarder.ProtocolsForStaking _protocol) public view returns (uint256) {
        return forwarder.getTotalClaimOf(_protocol);
    }

    // @notice get pending claim
    function getPendingClaims(address _baseToken) public view returns (uint256[] memory) {
        return pendingClaims[_baseToken].values();
    }

    /// @notice submit a withdrawal request from fund
    function requestWithdrawFund(address _token, uint256 _amount, address _recipient) public onlyOperator {
        if (_token == Constants.ETH_TOKEN) {
            require(address(this).balance >= _amount, "insufficent funds");
        } else {
            require(IERC20Upgradeable(_token).balanceOf(address(this)) >= _amount, "insufficent funds");
        }
        uint32 currentRequestId = controller.submitRequest(
            address(this),
            abi.encodeCall(IWithdraw.withdraw, (_token, _amount, _recipient))
        );
        emit RequestWithdrawFund(msg.sender, _token, _amount, _recipient, currentRequestId);
    }

    /// @notice perform withdrawal
    function withdraw(address _token, uint256 _amount, address _recipient) external onlyController {
        if (_token == Constants.ETH_TOKEN) {
            (bool sent, ) = _recipient.call{value: _amount}("");
            require(sent, "sent ETH failed");
            emit Withdraw(_token, _amount, address(this).balance);
        } else {
            IERC20Upgradeable(_token).safeTransfer(_recipient, _amount);
            emit Withdraw(_token, _amount, IERC20Upgradeable(_token).balanceOf(address(this)));
        }
    }

    /// @notice request withdraw
    function requestWithdraw(
        address _token,
        uint256 _amount,
        string memory _stakingProtocol,
        address _stakingAddress,
        address _tokenAddress,
        bytes memory _data
    ) external onlyController {
        (bool approveSuccess, bytes memory returnApproveData) = _tokenAddress.call(
            abi.encodeCall(IeETH.approve, (_stakingAddress, _amount))
        ); // aprove spender
        if (!approveSuccess) {
            revert(string(returnApproveData));
        }

        (bool success, bytes memory returnData) = _stakingAddress.call(_data);
        if (!success) {
            revert(string(returnData));
        }
        uint256 requestId;
        assembly {
            requestId := mload(add(returnData, 0x20)) // requestId from uint256
        }
        pendingClaims[_tokenAddress].add(requestId);
        emit RequestWithdraw(_token, _amount, address(this).balance, _stakingProtocol, _stakingAddress);
    }

    /// @notice claim withdraw after request withdraw has been approved
    function claimWithdraw(
        string memory _stakingProtocol,
        address _stakingAddress,
        address _tokenAddress,
        address _nftAddress,
        uint256 _nftId,
        bytes memory _data
    ) external onlyController {
        (bool success, bytes memory returnData) = _nftAddress.call(_data);
        if (!success) {
            revert(string(returnData));
        }
        pendingClaims[_tokenAddress].remove(_nftId);
        emit ClaimWithdraw(_nftId, _stakingProtocol, _stakingAddress, _tokenAddress, _nftAddress);
    }

    /// @notice withdraw and then stake in the respective protocol
    function withdrawAndStake(
        address _token,
        uint256 _amount,
        string memory _stakingProtocol,
        address _stakingAddress,
        bytes memory _data
    ) external onlyController {
        if (_token == Constants.ETH_TOKEN) {
            (bool success, ) = _stakingAddress.call{value: _amount}(_data);
            require(success, "stake failed in vault.sol");
        } else {
            (bool success, ) = _stakingAddress.call(_data);
            require(success, "stake failed in vault.sol");
        }

        emit WithdrawAndStake(_token, _amount, address(this).balance, _stakingProtocol, _stakingAddress);
    }

    /// @notice unstake from the give protocol (alternative option is withdraw and perform unstaking manually)
    function unstake(
        address _token,
        uint256 _amount,
        string memory _stakingProtocol,
        address _stakingAddress,
        bytes memory _data
    ) external onlyController {
        (bool success, ) = _stakingAddress.call(_data);
        require(success, "unstake failed in vault.sol");

        if (_token == Constants.ETH_TOKEN) {
            emit UnstakeAndDeposit(_token, _amount, address(this).balance, _stakingProtocol, _stakingAddress);
        } else {
            emit UnstakeAndDeposit(
                _token,
                _amount,
                IERC20Upgradeable(_token).balanceOf(address(this)),
                _stakingProtocol,
                _stakingAddress
            );
        }
    }

    /****************************************
     *          MODIFIER FUNCTIONS          *
     ****************************************/

    modifier onlyController() {
        require(msg.sender == address(controller), "only controller");
        _;
    }

    modifier onlyOperator() {
        require(controller.isOperator(msg.sender), "only operator");
        _;
    }

    modifier onlyAdmin() {
        require(controller.isAdmin(msg.sender), "Only admin");
        _;
    }
}
