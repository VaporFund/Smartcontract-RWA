// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "../interfaces/IMultiSigController.sol";

import "hardhat/console.sol";

contract CallMe {
    uint public i;

    IMultiSigController public controller;

    uint32 public currentRequestId;

    constructor(address _controller) {
        controller = IMultiSigController(_controller);
    }

    function callMe(uint j) public {
        i += j;
    }

    function getData() public pure returns (bytes memory) {
        return abi.encodeWithSignature("callMe(uint256)", 123);
    }

    function submit() public {
        currentRequestId = controller.submitRequest(address(this), getData());
    }
}
