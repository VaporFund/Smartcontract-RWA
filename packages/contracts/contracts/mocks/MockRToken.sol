//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "../interfaces/etherfi/IeTH.sol";

/*
 * @title MockRToken
 * @dev mock rebase token for testing
 */

contract MockRToken is IeETH {
    uint256 public totalShares;
    mapping(address => uint256) public shares;
    mapping(address => mapping(address => uint256)) public allowances;

    uint128 public totalValueOutOfLp;
    uint128 public totalValueInLp;

    error InvalidAmount();
    error SendFail();

    event TransferShares(address indexed from, address indexed to, uint256 sharesValue);

    function name() public pure returns (string memory) {
        return "rebase ETH";
    }

    function symbol() public pure returns (string memory) {
        return "rETH";
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function mint() public payable returns (uint256) {
        return _deposit(msg.sender, msg.value, 0);
    }

    function mintTo(address _recipient) public payable returns (uint256) {
        return _deposit(_recipient, msg.value, 0);
    }

    function burn(address _recipient, uint256 _amount) public returns (uint256) {
        uint256 share = sharesForWithdrawalAmount(_amount);
        // if (totalValueInLp < _amount || (msg.sender == address(withdrawRequestNFT) && ethAmountLockedForWithdrawal < _amount) || eETH.balanceOf(msg.sender) < _amount) revert InsufficientLiquidity();
        if (_amount > type(uint128).max || _amount == 0 || share == 0) revert InvalidAmount();

        totalValueInLp -= uint128(_amount);

        // ethAmountLockedForWithdrawal -= uint128(_amount);

        burnShares(msg.sender, share);

        (bool sent, ) = _recipient.call{value: _amount}("");
        if (!sent) revert SendFail();

        return share;
    }

    function rebase(int128 _accruedRewards) public {
        totalValueOutOfLp = uint128(int128(totalValueOutOfLp) + _accruedRewards);
    }

    function balanceOf(address _user) public view returns (uint256) {
        return getTotalEtherClaimOf(_user);
    }

    function getTotalEtherClaimOf(address _user) public view returns (uint256) {
        uint256 staked;
        if (totalShares > 0) {
            staked = (getTotalPooledEther() * shares[_user]) / totalShares;
        }
        return staked;
    }

    function getTotalPooledEther() public view returns (uint256) {
        return totalValueOutOfLp + totalValueInLp;
    }

    function approve(address _spender, uint256 _amount) public override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function burnShares(address _user, uint256 _share) public {
        require(shares[_user] >= _share, "BURN_AMOUNT_EXCEEDS_BALANCE");
        shares[_user] -= _share;
        totalShares -= _share;
    }

    function decreaseAllowance(address _spender, uint256 _decreaseAmount) public returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, _spender);
        require(currentAllowance >= _decreaseAmount, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, _spender, currentAllowance - _decreaseAmount);
        }
        return true;
    }

    function increaseAllowance(address _spender, uint256 _increaseAmount) public returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, _spender);
        _approve(owner, _spender, currentAllowance + _increaseAmount);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowances[_owner][_spender];
    }

    function mintShares(address _user, uint256 _share) public {
        shares[_user] += _share;
        totalShares += _share;
    }

    function transfer(address _recipient, uint256 _amount) public returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function sharesForAmount(uint256 _amount) public view returns (uint256) {
        uint256 totalPooledEther = getTotalPooledEther();
        if (totalPooledEther == 0) {
            return 0;
        }
        return (_amount * totalShares) / totalPooledEther;
    }

    function _transfer(address _sender, address _recipient, uint256 _amount) internal {
        uint256 _sharesToTransfer = sharesForAmount(_amount);
        _transferShares(_sender, _recipient, _sharesToTransfer);
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) external returns (bool) {
        uint256 currentAllowance = allowances[_sender][msg.sender];
        require(currentAllowance >= _amount, "TRANSFER_AMOUNT_EXCEEDS_ALLOWANCE");
        unchecked {
            _approve(_sender, msg.sender, currentAllowance - _amount);
        }
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    // INTERNAL

    function _transferShares(address _sender, address _recipient, uint256 _sharesAmount) internal {
        require(_sender != address(0), "TRANSFER_FROM_THE_ZERO_ADDRESS");
        require(_recipient != address(0), "TRANSFER_TO_THE_ZERO_ADDRESS");
        require(_sharesAmount <= shares[_sender], "TRANSFER_AMOUNT_EXCEEDS_BALANCE");

        shares[_sender] -= _sharesAmount;
        shares[_recipient] += _sharesAmount;
    }

    function _approve(address _owner, address _spender, uint256 _amount) internal {
        require(_owner != address(0), "APPROVE_FROM_ZERO_ADDRESS");
        require(_spender != address(0), "APPROVE_TO_ZERO_ADDRESS");

        allowances[_owner][_spender] = _amount;
    }

    function _deposit(address _recipient, uint256 _amountInLp, uint256 _amountOutOfLp) internal returns (uint256) {
        totalValueInLp += uint128(_amountInLp);
        totalValueOutOfLp += uint128(_amountOutOfLp);
        uint256 amount = _amountInLp + _amountOutOfLp;
        uint256 share = _sharesForDepositAmount(amount);
        if (amount > type(uint128).max || amount == 0 || share == 0) revert InvalidAmount();

        mintShares(_recipient, share);

        return share;
    }

    function _sharesForDepositAmount(uint256 _depositAmount) internal view returns (uint256) {
        uint256 totalPooledEther = getTotalPooledEther() - _depositAmount;
        if (totalPooledEther == 0) {
            return _depositAmount;
        }
        return (_depositAmount * totalShares) / totalPooledEther;
    }

    function sharesForWithdrawalAmount(uint256 _amount) public view returns (uint256) {
        uint256 totalPooledEther = getTotalPooledEther();
        if (totalPooledEther == 0) {
            return 0;
        }

        // ceiling division so rounding errors favor the protocol
        uint256 numerator = _amount * totalShares;
        return (numerator + totalPooledEther - 1) / totalPooledEther;
    }
}
