// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IVaultRwa.sol";
import "./Ownable.sol";

/*
 * @title YieldBearingToken
 * @dev A yield token is a token able to reward profit; it is basically an EC20 token.
 */

contract YieldBearingToken is IERC20, Ownable {
    /// @dev token metadata
    string public name;
    string public symbol;
    uint8 public decimals;

    /// @dev rebase variants
    uint256 public totalShares;
    mapping(address => uint256) public shares;
    mapping(address => mapping(address => uint256)) public allowances;
    IVaultRwa public vault;

    error InvalidAmount();
    error SendFail();

    event TransferShares(address indexed from, address indexed to, uint256 sharesValue);

    constructor(string memory _name, string memory _symbol, uint8 _decimals, address _owner) Ownable(_owner) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        vault = IVaultRwa(_owner);
    }

    function mintShares(address _user, uint256 _share) external onlyOwner {
        shares[_user] += _share;
        totalShares += _share;

        emit Transfer(address(0), _user, _share);
        emit TransferShares(address(0), _user, _share);
    }

    function burnShares(address _user, uint256 _share) external {
        require(msg.sender == address(vault) || msg.sender == _user, "Incorrect Caller");
        require(shares[_user] >= _share, "BURN_AMOUNT_EXCEEDS_BALANCE");
        shares[_user] -= _share;
        totalShares -= _share;

        emit Transfer(_user, address(0), _share);
        emit TransferShares(_user, address(0), _share);
    }

    function transfer(address _recipient, uint256 _amount) external override(IERC20) returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(address _spender, uint256 _amount) external override(IERC20) returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function increaseAllowance(address _spender, uint256 _increaseAmount) external returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, _spender);
        _approve(owner, _spender, currentAllowance + _increaseAmount);
        return true;
    }

    function decreaseAllowance(address _spender, uint256 _decreaseAmount) external returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, _spender);
        require(currentAllowance >= _decreaseAmount, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, _spender, currentAllowance - _decreaseAmount);
        }
        return true;
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external override(IERC20) returns (bool) {
        uint256 currentAllowance = allowances[_sender][msg.sender];
        require(currentAllowance >= _amount, "TRANSFER_AMOUNT_EXCEEDS_ALLOWANCE");
        unchecked {
            _approve(_sender, msg.sender, currentAllowance - _amount);
        }
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    // [INTERNAL FUNCTIONS]
    function _transfer(address _sender, address _recipient, uint256 _amount) internal {
        _transferShares(_sender, _recipient, _amount);
        emit Transfer(_sender, _recipient, _amount);
    }

    function _approve(address _owner, address _spender, uint256 _amount) internal {
        require(_owner != address(0), "APPROVE_FROM_ZERO_ADDRESS");
        require(_spender != address(0), "APPROVE_TO_ZERO_ADDRESS");

        allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    function _transferShares(address _sender, address _recipient, uint256 _sharesAmount) internal {
        require(_sender != address(0), "TRANSFER_FROM_THE_ZERO_ADDRESS");
        require(_recipient != address(0), "TRANSFER_TO_THE_ZERO_ADDRESS");
        require(_sharesAmount <= shares[_sender], "TRANSFER_AMOUNT_EXCEEDS_BALANCE");

        shares[_sender] -= _sharesAmount;
        shares[_recipient] += _sharesAmount;

        emit TransferShares(_sender, _recipient, _sharesAmount);
    }

    // [GETTERS]
    function totalSupply() public view returns (uint256) {
        return totalShares;
    }

    function balanceOf(address _user) public view override(IERC20) returns (uint256) {
        return shares[_user];
    }
}
