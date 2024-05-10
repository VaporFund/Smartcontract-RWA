// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

contract Oracle is OwnableUpgradeable {
    using AddressUpgradeable for address;

    uint256 public updateLimit;
    uint256 public numConfirmationsRequired;

    struct TokenPairData {
        uint256[] aprs;
        uint256[] totalShares;
        uint256[] totalValueOfLps;
        uint256[] updatedAt;
    }

    struct TempPairData {
        bytes32 keyPair;
        uint256 apr;
        uint256 totalShare;
        uint256 totalValueOfLp;
    }

    mapping(bytes32 => TokenPairData) private tokenPairData;
    TempPairData[] public tempTokenPairData;
    mapping(address => bool) public isConfirmer;
    mapping(uint256 => address[]) public confirmers;

    modifier onlyConfirmer() {
        require(isConfirmer[_msgSender()], "Only confirmer");
        _;
    }

    event DataUpdated(bytes32 indexed keyPair, uint256 apr, uint256 totalShare, uint256 totalValueOfLp);

    event SubmitData(bytes32 indexed keyPair, uint256 submitId);

    event ConfirmSubmit(uint256 submitId, address confirmer);

    function initialize() external initializer {
        OwnableUpgradeable.__Ownable_init();
        updateLimit = 2 hours;
        numConfirmationsRequired = 1;
    }

    function submitData(address _tokenA, address _tokenB, uint256 _apr, uint256 _totalShare, uint256 _totalValueOfLp) external onlyConfirmer {
        bytes32 keyPair = keccak256(abi.encodePacked(_tokenA, _tokenB));
        uint256 submitId = tempTokenPairData.length;
        tempTokenPairData.push(TempPairData({keyPair: keyPair, apr: _apr, totalShare: _totalShare, totalValueOfLp: _totalValueOfLp}));
        confirmers[submitId].push(_msgSender());
        emit SubmitData(keyPair, submitId);
    }

    function confirmSubmit(uint256 _submitId) external onlyConfirmer {
        for (uint256 index; index < confirmers[_submitId].length; index++) {
            require(confirmers[_submitId][index] != _msgSender(), "You already confirmed");
        }
        confirmers[_submitId].push(_msgSender());
        if (confirmers[_submitId].length >= numConfirmationsRequired) {
            bytes32 keyPair = tempTokenPairData[_submitId].keyPair;
            tokenPairData[keyPair].aprs.push(tempTokenPairData[_submitId].apr);
            tokenPairData[keyPair].totalShares.push(tempTokenPairData[_submitId].totalShare);
            tokenPairData[keyPair].totalValueOfLps.push(tempTokenPairData[_submitId].totalValueOfLp);
            tokenPairData[keyPair].updatedAt.push(block.timestamp);

            emit DataUpdated(tempTokenPairData[_submitId].keyPair, tempTokenPairData[_submitId].apr, tempTokenPairData[_submitId].totalShare, tempTokenPairData[_submitId].totalValueOfLp);
        }
        emit ConfirmSubmit(_submitId, _msgSender());
    }

    function getData(address _tokenA, address _tokenB) external view returns (uint256, uint256, uint256, uint256) {
        bytes32 keyPair = keccak256(abi.encodePacked(_tokenA, _tokenB));
        TokenPairData storage pairData = tokenPairData[keyPair];
        uint256 lastIndex = pairData.aprs.length - 1;

        return (pairData.aprs[lastIndex], pairData.totalShares[lastIndex], pairData.totalValueOfLps[lastIndex], pairData.updatedAt[lastIndex]);
    }

    function setUpdateLimit(uint256 _updateLimit) external onlyOwner {
        updateLimit = _updateLimit;
    }

    function setNumConfirmationsRequired(uint256 _numConfirmationsRequired) external onlyOwner {
        numConfirmationsRequired = _numConfirmationsRequired;
    }

    function setIsConfirmer(address _address, bool _status) external onlyOwner {
        isConfirmer[_address] = _status;
    }

    function getConfirmers(uint256 index) external view returns (address[] memory) {
        return confirmers[index];
    }
}
