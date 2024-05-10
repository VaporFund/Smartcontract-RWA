//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "./MockRToken.sol";
import "./MockERC20.sol";
import "../interfaces/IMockDepositPool.sol";
import "../interfaces/etherfi/IeTH.sol";

import "hardhat/console.sol";

contract MockDepositPool is IMockDepositPool {
    MockRToken public rToken;

    MockERC20 public usdc; // test usdc->usdy flow
    MockERC20 public usdy; // no rebase

    constructor() {
        rToken = new MockRToken();

        usdc = new MockERC20("MOCK USDC", "USDC", 18);
        usdy = new MockERC20("MOCK USDY", "USDY", 18);
    }

    function rTokenAddress() external view returns (address) {
        return address(rToken);
    }

    function usdcAddress() external view returns (address) {
        return address(usdc);
    }

    function usdyAddress() external view returns (address) {
        return address(usdy);
    }

    function deposit() external payable returns (uint256) {
        return rToken.mintTo{value: msg.value}(msg.sender);
    }

    function withdraw(address recipient, uint256 amount) external returns (uint256) {
        IeETH token = IeETH(address(rToken));
        token.transferFrom(msg.sender, address(this), amount);
        return rToken.burn(recipient, amount);
    }

    function depositUsdc(uint256 amountIn) external {
        usdc.transferFrom(msg.sender, address(this), amountIn);
        usdy.mintTo(msg.sender, amountIn);
    }

    function withdrawUsdc(address recipient, uint256 amount) external {
        usdy.burn(msg.sender, amount);
        usdc.transfer(recipient, amount);
    }

    function rebase(int128 _accruedRewards) external {
        rToken.rebase(_accruedRewards);
    }

    function addEthAmountLockedForWithdrawal() external payable {
        require(msg.value > 0, "invalid value");
    }
}
