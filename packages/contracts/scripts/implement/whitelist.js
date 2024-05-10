const { ethers } = require("hardhat");
const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");


async function main() {
    const contractAddress = "0x27365Fd5F00e1AeA4D63e1E36d7b8e24fcf837Ad";
    const [operator, bob, charlie, dave] = await ethers.getSigners();

    // Fetching existing contract by address
    const contract = await ethers.getContractAt("WhitelistManager", contractAddress);

    // Add and verify admin status
    const adminAddress = operator.address;
    const tx = await contract.setStatusAdmin(adminAddress, true);
    await tx.wait()
    const isAdmin = await contract.admins(adminAddress);
    console.log(`Admin status for ${adminAddress}: ${isAdmin}`);

    // Add and verify Merkle root
    const inWhitelist = Array.from({ length: 100 }, () => ethers.Wallet.createRandom());
    const leaves = inWhitelist.map(account => [account.address]);
    const tree = StandardMerkleTree.of(leaves, ["address"]);
    const merkleRoot = tree.root;
    let tx2 = await contract.connect(operator).setRoot(merkleRoot, true);
    await tx2.wait()
    const isActive = await contract.merkleRoots(merkleRoot);
    console.log(`Merkle root status: ${isActive}`);

    // Verify address in whitelist using Merkle proof
    const addressToVerify = inWhitelist[0].address;
    const proof = tree.getProof([addressToVerify]);
    const isInWhitelist = await contract.isInWhitelist(merkleRoot, addressToVerify, proof);
    console.log(`Address ${addressToVerify} in whitelist: ${isInWhitelist}`);

    // Verify false address in whitelist using Merkle proof
    await contract.connect(operator).setStatusDisableAddress(addressToVerify, true);
    const isFalseInWhitelist = await contract.isInWhitelist(merkleRoot, addressToVerify, proof);
    console.log(`Address ${addressToVerify} in whitelist after disabling: ${isFalseInWhitelist}`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});