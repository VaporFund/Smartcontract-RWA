// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/hashnote/IYieldTokenOracle.sol";
import "../interfaces/hashnote/IYieldToken.sol";
import "../libs/hashnote/FixedPointMathLib.sol";
import "../interfaces/hashnote/IYieldTokenTellerV2.sol";
import "../interfaces/hashnote/IHashnoteHelper.sol";

contract HashnoteHelper is IHashnoteHelper {
    using FixedPointMathLib for uint256;
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IYieldToken;

    uint256 public constant BASIC_POINT = 10 ** 10;

    IYieldToken public immutable yieldToken;
    uint8 private immutable yieldTokenDecimals;

    IERC20Metadata public immutable stableToken;
    uint8 private immutable stableDecimals;

    IYieldTokenOracle public immutable oracle;
    uint8 private immutable oracleDecimals;

    IYieldTokenTellerV2 public immutable yieldTokenTellerV2;

    error BadAddress();

    constructor(address _yieldToken, address _stableToken, address _oracle, address _teller) {
        if (_yieldToken == address(0)) revert BadAddress();
        if (_stableToken == address(0)) revert BadAddress();
        if (_oracle == address(0)) revert BadAddress();
        if (_teller == address(0)) revert BadAddress();

        yieldToken = IYieldToken(_yieldToken);
        yieldTokenDecimals = yieldToken.decimals();

        stableToken = IERC20Metadata(_stableToken);
        stableDecimals = stableToken.decimals();

        oracle = IYieldTokenOracle(_oracle);
        oracleDecimals = oracle.decimals();

        yieldTokenTellerV2 = IYieldTokenTellerV2(_teller);
    }

    // stableToken to yieldToken
    function buyPreview(
        uint256 _stableTokenAmount
    ) public view returns (uint256 yieldTokenAmount, uint256 fee, int256 price) {
        (yieldTokenAmount, fee, price) = yieldTokenTellerV2.buyPreview(_stableTokenAmount);
    }

    // yieldToken to stableToken
    function sellPreview(
        uint256 _yieldTokenAmount
    ) public view returns (uint256 stableTokenAmount, uint256 fee, int256 price) {
        (stableTokenAmount, fee, price) = yieldTokenTellerV2.sellPreview(_yieldTokenAmount);
    }

    function calculationPercentInterestPerRound() public view returns (uint256 _percent, int256 _price) {
        uint80 roundId;
        (roundId, _price, , , ) = oracle.latestRoundData();

        // using the last reported interest amount to calculate the fee
        // balance USD (2 decimals)
        // interest accrued USD (2 decimals)
        // totalSupply accrued USD (6 decimals)
        (, uint256 balance, uint256 interest, , ) = oracle.getRoundDetails(roundId);
        _percent = (interest * BASIC_POINT) / balance;
        return (_percent, _price);
    }

    function getTotalStableTokenByYieldToken(address _vault) public view returns (uint256) {
        uint256 balanceYToken = yieldToken.balanceOf(_vault);
        (uint256 balanceSToken, , ) = sellPreview(balanceYToken);
        return balanceSToken;
    }

    function encodeCallBuyFor(uint256 _amount, address _recipient) public pure returns (bytes memory) {
        return abi.encodeWithSelector(bytes4(keccak256("buyFor(uint256,address)")), _amount, _recipient);
    }

    function encodeCallSellFor(uint256 _amount, address _recipient) public pure returns (bytes memory) {
        return abi.encodeWithSelector(bytes4(keccak256("sellFor(uint256,address)")), _amount, _recipient);
    }

    function teller() public view returns (address) {
        return address(yieldTokenTellerV2);
    }
}
