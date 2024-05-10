const { ethers, upgrades } = require("hardhat");
const { StandardMerkleTree } = require("@openzeppelin/merkle-tree"); // Change import to require
const { verifyImplementContract, verifyContract } = require("./verifyUtils");

async function deployContracts() {
    const vaultAddress = "0x6B72A34587a281C7787546Ec4f4eb1dd37924666"; //contract address for vault
    try {
        await hre.run("verify:verify", {
            address: vaultAddress,
            constructorArguments: [],
        });
        console.log(`Contract verified: ${vaultAddress}`);
    } catch (error) {
        console.error(`Error verifying contract ${vaultAddress}:`, error);
    }
}
deployContracts().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});