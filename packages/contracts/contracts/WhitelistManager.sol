// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Arrays.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract WhitelistManager is Ownable {
    event RootAdded(bytes32 indexed _root, bool indexed _isActive);
    event AdminAdded(address indexed _address, bool indexed _isAdmin);
    event OracleAdded(address indexed _oracle);
    event DisableWhitelistEvent(bool indexed _status);
    event DisableAddressEvent(bytes32 indexed _leaf, bool indexed _status);

    using Arrays for bytes32[];

    mapping(address => bool) public admins;
    mapping(bytes32 => bool) public merkleRoots;
    mapping(bytes32 => bool) public disabledMerkleLeaves;

    bool public isWhitelistDisabled;
    address public oracle;

    modifier onlyAdminOrOwner() {
        require(admins[_msgSender()] || _msgSender() == owner(), "Only admin or owner");
        _;
    }

    constructor() {
        isWhitelistDisabled = false;
    }

    /**
     * @dev Checks if an address is in the whitelist using Merkle proof.
     * @param _merkleRoot The Merkle root to check against.
     * @param _address The address to check.
     * @param _proof Merkle proof of inclusion of the address.
     * @return True if the address is in the whitelist, false otherwise.
     */
    function isInWhitelist(
        bytes32 _merkleRoot,
        address _address,
        bytes32[] memory _proof
    ) external view returns (bool) {
        if (isWhitelistDisabled) return true;
        if (!merkleRoots[_merkleRoot]) return false;
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_address))));
        if (disabledMerkleLeaves[leaf]) return false;
        return MerkleProof.verify(_proof, _merkleRoot, leaf);
    }

    /**
     * @dev Sets the admin status of an address.
     * @param _address The address to set admin status for.
     * @param _isAdmin True if the address should be an admin, false otherwise.
     */
    function setStatusAdmin(address _address, bool _isAdmin) external onlyOwner {
        admins[_address] = _isAdmin;
        emit AdminAdded(_address, _isAdmin);
    }

    /**
     * @dev Sets the oracle address.
     * @param _oracle The address to set oracle for.
     */
    function setOracle(address _oracle) external onlyOwner {
        oracle = _oracle;
        emit OracleAdded(oracle);
    }

    /**
     * @dev Sets the status of the whitelist.
     * @param _isDisabled True if the whitelist should be disabled, false otherwise.
     */
    function setStatusDisableWhitelist(bool _isDisabled) external onlyAdminOrOwner {
        isWhitelistDisabled = _isDisabled;
        emit DisableWhitelistEvent(_isDisabled);
    }

    /**
     * @dev Sets the status of the address.
     * @param _isDisabled True if the leaf should be disabled, false otherwise.
     */
    function setStatusDisableAddress(address _address, bool _isDisabled) external onlyAdminOrOwner {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_address))));
        disabledMerkleLeaves[leaf] = _isDisabled;
        emit DisableAddressEvent(leaf, _isDisabled);
    }

    /**
     * @dev Adds a Merkle root with its status.
     * @param _root The Merkle root to add.
     * @param _isActive True if the Merkle root is active, false otherwise.
     */
    function setRoot(bytes32 _root, bool _isActive) external onlyAdminOrOwner {
        merkleRoots[_root] = _isActive;
        emit RootAdded(_root, _isActive);
    }

    /**
     * @dev Adds a Merkle root with its status.
     * @param _root The Merkle root to add.
     * @param _signatureExpTime is address in whitelist.
     * @param _signature is signature.
     *
     */
    function setRootActiveBySignature(bytes32 _root, bytes memory _signature, uint256 _signatureExpTime) external {
        require(_signatureExpTime > block.timestamp, "Signature expired");
        require(verifyWhitelist(_root, _signatureExpTime, _signature), "Signature invalidate");
        merkleRoots[_root] = true;
        emit RootAdded(_root, true);
    }

    function verifyWhitelist(
        bytes32 _root,
        uint256 _signatureExpTime,
        bytes memory _signature
    ) private view returns (bool) {
        bytes32 dataHash = encodeWhiteListSignature(_root, _signatureExpTime);
        bytes32 signHash = ECDSA.toEthSignedMessageHash(dataHash);
        address recovered = ECDSA.recover(signHash, _signature);
        return recovered == oracle;
    }

    function encodeWhiteListSignature(bytes32 _root, uint256 _signatureExpTime) private view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return keccak256(abi.encode(chainId, _root, _signatureExpTime));
    }
}
