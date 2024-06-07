// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../interfaces/IMultiSigController.sol";
import "../interfaces/IVaultStakingETH.sol";
import "../interfaces/IMockDepositPool.sol";
import "../interfaces/etherfi/ILiquidityPool.sol";
import "../interfaces/IForwarder.sol";
import "../interfaces/etherfi/IWithdrawRequestNFT.sol";

import {IWithdraw} from "./VaultStakingETH.sol";
import {Constants} from "../utility/Constants.sol";

/*
 * @title Forwarder
 * @dev a vault contract wrapper that interfaces with external protocols (ether.fi / hashnote) and keeps updating to support additional ones
 */

contract Forwarder is Initializable, IForwarder {
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev controller for multi-sig operations
    IMultiSigController public controller;

    /// @dev main's vault on the chain
    IVaultStakingETH public vault;

    /// @dev registry address for all supported protocols
    mapping(ProtocolsForStaking => ProtocolInfo) public registry;

    event RequestStake(uint32 indexed requestId, string stakingProtocol, address stakingAddress, address tokenAddress, uint256 amount, address indexed operator);
    event RequestWithdraw(uint32 indexed requestId, string stakingProtocol, address stakingAddress, uint256 amount, address indexed operator);
    event RequestUnstake(uint32 indexed requestId, string stakingProtocol, address stakingAddress, address tokenAddress, uint256 amount, address indexed operator);
    event ClaimWithdraw(uint32 indexed requestId, string stakingProtocol, address stakingAddress, address tokenAddress, address nftAddress, address indexed operator);

    function initialize(address _controller, address _vault) external initializer {
        controller = IMultiSigController(_controller);
        vault = IVaultStakingETH(_vault);
    }

    function getLpStakingAddress(ProtocolsForStaking _protocol) public view returns (address) {
        return registry[_protocol].registryAddress;
    }

    function getTotalClaimOf(ProtocolsForStaking _protocol) public view returns (uint256) {
        if (_protocol == ProtocolsForStaking.ETHERFI) {
            return ILiquidityPool(registry[_protocol].registryAddress).getTotalEtherClaimOf(address(vault));
        }
        return 0;
    }

    /// @notice stake asset from vault in respective protocol, output also locked in vault upon completion
    function requestStake(ProtocolsForStaking _protocol, address _tokenAddress, uint256 _amountIn) external onlyOperator {
        if (_protocol == ProtocolsForStaking.MOCK) _stakeMock(_tokenAddress, _amountIn);
        if (_protocol == ProtocolsForStaking.ETHERFI) _stakeEtherfi(_amountIn);
    }

    function requestWithdraw(ProtocolsForStaking _protocol, uint256 _unstakeAmount) external onlyOperator {
        if (_protocol == ProtocolsForStaking.ETHERFI) _requestWithdrawEtherfi(_unstakeAmount);
    }

    function requestClaimWithdraw(ProtocolsForStaking _protocol, uint256 nftId) external onlyOperator {
        if (_protocol == ProtocolsForStaking.ETHERFI) _claimWithdrawEtherfi(nftId);
    }

    /// @notice request unstaking from the protocol. Alternatively, unstaking manually could better fit most workflows
    function requestUnstake(ProtocolsForStaking _protocol, address _tokenAddress, uint256 _unstakeAmount) external onlyOperator {
        require(IERC20Upgradeable(_tokenAddress).balanceOf(address(vault)) >= _unstakeAmount, "insufficient balance on vault.sol");

        if (_protocol == ProtocolsForStaking.MOCK) _unstakeMock(_tokenAddress, _unstakeAmount);
    }

    /// @notice register the protocol's interface contract address
    function register(ProtocolsForStaking _protocol, address _registryAddress, address _tokenAddress, address _nftAddress) external onlyOperator {
        registry[_protocol] = ProtocolInfo({registryAddress: _registryAddress, tokenAddress: _tokenAddress, nftAddress: _nftAddress});
    }

    /****************************************
     *          INTERNAL FUNCTIONS          *
     ****************************************/

    function _stakeMock(address _tokenAddress, uint256 _amountIn) internal {
        if (_tokenAddress == Constants.ETH_TOKEN) {
            uint32 currentRequestId = controller.submitRequest(address(vault), abi.encodeCall(IWithdraw.withdrawAndStake, (_tokenAddress, _amountIn, "MOCK", registry[ProtocolsForStaking.MOCK].registryAddress, abi.encodeCall(IMockDepositPool.deposit, ()))));

            emit RequestStake(currentRequestId, "MOCK", registry[ProtocolsForStaking.MOCK].registryAddress, _tokenAddress, _amountIn, msg.sender);
        } else {
            uint32 currentRequestId = controller.submitRequest(address(vault), abi.encodeCall(IWithdraw.withdrawAndStake, (_tokenAddress, _amountIn, "MOCK", registry[ProtocolsForStaking.MOCK].registryAddress, abi.encodeCall(IMockDepositPool.depositUsdc, (_amountIn)))));

            emit RequestStake(currentRequestId, "MOCK", registry[ProtocolsForStaking.MOCK].registryAddress, _tokenAddress, _amountIn, msg.sender);
        }
    }

    function _unstakeMock(address _tokenAddress, uint256 _unstakeAmount) internal {
        address rTokenAddress = IMockDepositPool(registry[ProtocolsForStaking.MOCK].registryAddress).rTokenAddress();

        if (_tokenAddress == rTokenAddress) {
            uint32 currentRequestId = controller.submitRequest(address(vault), abi.encodeCall(IWithdraw.unstake, (_tokenAddress, _unstakeAmount, "MOCK", registry[ProtocolsForStaking.MOCK].registryAddress, abi.encodeCall(IMockDepositPool.withdraw, (address(vault), _unstakeAmount)))));

            emit RequestUnstake(currentRequestId, "MOCK", registry[ProtocolsForStaking.MOCK].registryAddress, _tokenAddress, _unstakeAmount, msg.sender);
        } else {
            uint32 currentRequestId = controller.submitRequest(address(vault), abi.encodeCall(IWithdraw.unstake, (_tokenAddress, _unstakeAmount, "MOCK", registry[ProtocolsForStaking.MOCK].registryAddress, abi.encodeCall(IMockDepositPool.withdrawUsdc, (address(vault), _unstakeAmount)))));

            emit RequestUnstake(currentRequestId, "MOCK", registry[ProtocolsForStaking.MOCK].registryAddress, _tokenAddress, _unstakeAmount, msg.sender);
        }
    }

    //-------------------------------------etherfi-------------------------------------
    function _stakeEtherfi(uint256 _amountIn) internal {
        uint32 currentRequestId = controller.submitRequest(address(vault), abi.encodeCall(IWithdraw.withdrawAndStake, (Constants.ETH_TOKEN, _amountIn, "ETHERFI", registry[ProtocolsForStaking.ETHERFI].registryAddress, abi.encodeCall(ILiquidityPool.deposit, ()))));

        emit RequestStake(currentRequestId, "ETHERFI", registry[ProtocolsForStaking.ETHERFI].registryAddress, Constants.ETH_TOKEN, _amountIn, msg.sender);
    }

    function _requestWithdrawEtherfi(uint256 _unstakeAmount) internal {
        uint32 currentRequestId = controller.submitRequest(address(vault), abi.encodeCall(IWithdraw.requestWithdraw, (Constants.ETH_TOKEN, _unstakeAmount, "ETHERFI", registry[ProtocolsForStaking.ETHERFI].registryAddress, registry[ProtocolsForStaking.ETHERFI].tokenAddress, abi.encodeCall(ILiquidityPool.requestWithdraw, (address(vault), _unstakeAmount)))));

        emit RequestWithdraw(currentRequestId, "ETHERFI", registry[ProtocolsForStaking.ETHERFI].registryAddress, _unstakeAmount, msg.sender);
    }

    function _claimWithdrawEtherfi(uint256 _nftId) internal {
        uint32 currentRequestId = controller.submitRequest(address(vault), abi.encodeCall(IWithdraw.claimWithdraw, ("ETHERFI", registry[ProtocolsForStaking.ETHERFI].registryAddress, registry[ProtocolsForStaking.ETHERFI].tokenAddress, registry[ProtocolsForStaking.ETHERFI].nftAddress, _nftId, abi.encodeCall(IWithdrawRequestNFT.claimWithdraw, _nftId))));

        emit ClaimWithdraw(currentRequestId, "ETHERFI", registry[ProtocolsForStaking.ETHERFI].registryAddress, registry[ProtocolsForStaking.ETHERFI].tokenAddress, registry[ProtocolsForStaking.ETHERFI].nftAddress, msg.sender);
    }

    modifier onlyOperator() {
        require(controller.isOperator(msg.sender), "only operator");
        _;
    }
}
