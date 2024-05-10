//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/*
 * @title WithdrawRequestNFT
 * @dev NFT ERC-721 represents a withdrawal request
 */

contract WithdrawRequestNFT is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    address public vault;

    /// @dev mapping of token ID to token address for withdrawal
    mapping(uint256 => address) private tokenAddresses;

    /// @dev mapping of token ID to withdrawal amount
    mapping(uint256 => uint256) private tokenAmount;

    constructor(address _vault) ERC721("Withdraw Request NFT", "WithdrawRequestNFT") {
        vault = _vault;
    }

    function mint(address _token, uint256 _amount, address _recipient) external onlyVault returns (uint256) {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();

        _mint(_recipient, newItemId);

        tokenAddresses[newItemId] = _token;
        tokenAmount[newItemId] = _amount;
        return newItemId;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        string memory jsonPreImage = string.concat(string.concat(string.concat('{"name": "VaporFund Withdraw NFT #', Strings.toString(id)), '","description":"NFT ERC-721 represents a withdrawal request","external_url":"https://www.vaporfund.com","image":"'), string.concat("https://www.vaporfund.com/logo.png"));
        string memory jsonPostImage = string.concat('","attributes":[{"trait_type":"Token to be Withdrawal","value":"', Strings.toHexString(tokenAddresses[id]), '"},{"trait_type":"Withdraw Amount","value":"', Strings.toString(tokenAmount[id]));
        string memory jsonPostTraits = '"}]}';

        return string.concat("data:application/json;utf8,", string.concat(string.concat(jsonPreImage, jsonPostImage), jsonPostTraits));
    }

    function getTokenAmount(uint256 id) public view returns (uint256) {
        return tokenAmount[id];
    }

    function getTokenAddress(uint256 id) public view returns (address) {
        return tokenAddresses[id];
    }

    /****************************************
     *          INTERNAL FUNCTIONS          *
     ****************************************/

    modifier onlyVault() {
        require(msg.sender == address(vault), "only vault");
        _;
    }
}
