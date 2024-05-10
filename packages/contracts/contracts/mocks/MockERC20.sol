//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    uint8 _d;

    constructor(string memory name, string memory symbol, uint8 _decimals) ERC20(name, symbol) {
        _d = _decimals;
    }

    function decimals() public view virtual override returns (uint8) {
        return _d;
    }

    function mint(uint256 _amount) public {
        _mint(msg.sender, _amount);
    }

    function mintTo(address _recipient, uint256 _amount) public {
        _mint(_recipient, _amount);
    }

    function burn(address _recipient, uint256 _amount) public {
        _burn(_recipient, _amount);
    }
}
