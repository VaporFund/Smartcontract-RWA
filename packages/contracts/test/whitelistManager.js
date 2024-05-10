const { ethers } = require("hardhat");
const { expect } = require("chai");
const { StandardMerkleTree } = require("@openzeppelin/merkle-tree"); // Change import to require

describe("#whitelist-manager", () => {
    let whitelistManager;
    let accounts;
    let inWhitelist;

    before(async() => {
        accounts = await ethers.getSigners();
        inWhitelist = Array.from({ length: 100 }, () => ethers.Wallet.createRandom());
        const WhitelistManager = await ethers.getContractFactory("WhitelistManager");
        whitelistManager = await WhitelistManager.deploy();
    });

    beforeEach(async() => {});

    it("should add and verify admin status", async() => {
        const adminAddress = accounts[1].address;
        await whitelistManager.setStatusAdmin(adminAddress, true);
        const isAdmin = await whitelistManager.admins(adminAddress);
        expect(isAdmin).to.be.true;
    });

    it("should add and verify Merkle root", async() => {
        const leaves = inWhitelist.map(account => [account.address]);
        const tree = StandardMerkleTree.of(leaves, ["address"]);
        const merkleRoot = tree.root;
        await whitelistManager.setRoot(merkleRoot, true);
        const isActive = await whitelistManager.merkleRoots(merkleRoot);
        expect(isActive).to.be.true;
    });

    it("should verify address in whitelist using Merkle proof", async() => {
        const leaves = inWhitelist.map(account => [account.address]);
        const merkleTree = StandardMerkleTree.of(leaves, ["address"]);
        const merkleRoot = merkleTree.root;
        await whitelistManager.setRoot(merkleRoot, true);
        const addressToVerify = inWhitelist[0].address;
        const proof = merkleTree.getProof([addressToVerify]);
        const isInWhitelist = await whitelistManager.isInWhitelist(merkleRoot, addressToVerify, proof);
        expect(isInWhitelist).to.be.true;
    });

    it("should verify false address in whitelist using Merkle proof", async() => {
        const leaves = inWhitelist.map(account => [account.address]);
        const merkleTree = StandardMerkleTree.of(leaves, ["address"]);
        const merkleRoot = merkleTree.root;
        await whitelistManager.setRoot(merkleRoot, true);
        const addressToVerify = inWhitelist[0].address;
        const proof = merkleTree.getProof([addressToVerify]);
        await whitelistManager.setStatusDisableAddress(addressToVerify, true);
        const isInWhitelist = await whitelistManager.isInWhitelist(merkleRoot, addressToVerify, proof);
        expect(isInWhitelist).to.be.false;
    });

    it("should add root use signature", async() => {
        const leave = ethers.Wallet.createRandom();
        const oracle = accounts[2];
        await whitelistManager.setOracle(oracle.address);

        const merkleTree = StandardMerkleTree.of([
            [leave.address]
        ], ["address"]);
        const merkleRoot = merkleTree.root;

        // generate signature
        const signatureExpTime = 9999999999999;
        const signature = generateWhiteSignature(merkleRoot, signatureExpTime, oracle)

        await whitelistManager.setRootActiveBySignature(merkleRoot, signature, signatureExpTime);
        const proof = merkleTree.getProof([leave.address]);
        const isInWhitelist = await whitelistManager.isInWhitelist(merkleRoot, leave, proof);
        expect(isInWhitelist).to.be.true


    });
});

const generateWhiteSignature = async(_root, _signatureExpTime, signer) => {
    const { chainId } = await ethers.provider.getNetwork();
    return signer.signMessage(ethers.getBytes(encodeWhitelistData(chainId, _root, _signatureExpTime)));
};

const encodeWhitelistData = (_chainId, _root, _signatureExpTime) => {
    const payload = ethers.AbiCoder.defaultAbiCoder().encode(["uint256", "bytes32", "uint256"], [_chainId, _root, _signatureExpTime]);
    return ethers.keccak256(payload);
};

module.exports = {
    generateWhiteSignature,
    encodeWhitelistData
}