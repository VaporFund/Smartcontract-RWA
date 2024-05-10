const { ethers, upgrades } = require("hardhat");
const { verifyImplementContract, verifyContract } = require("../../verifyUtils");

const vaultAddress = "0x38efCc435b677d8c68bC48A4F2EDFDA1eD2917F3"; // proxy address vault
const whitelistManagerAddress = "0xb4f7b648be3158421bd73846c7cd0093674fe8d5"; // proxy address vault

async function main() {
    const VaultRwa = await ethers.getContractFactory("VaultRwa")

    //for try deploy
    const vault = await ethers.getContractAt("VaultRwa", vaultAddress);

    const [admin] = await ethers.getSigners()
    console.log("admin: ", admin.address)

    const vaultProxy = await upgrades.upgradeProxy(vaultAddress, VaultRwa);
    const vaultProxyAddress = await vaultProxy.target;
    const vaultAddressImplement = await upgrades.erc1967.getImplementationAddress(vaultProxyAddress);
    const contractAddress = {
        vaultProxyAddress: vaultProxyAddress,
        vaultAddressImplement: vaultAddressImplement,
    };
    console.table(contractAddress);

    // //set whitelist for vault
    // const whitelistManager = await ethers.getContractAt("WhitelistManager", whitelistManagerAddress);
    // await vault.setWhitelistManager(whitelistManager.target);


    for (let i = 0; i < 3; i++) {
        //verify vault rwa
        await verifyContract(vault, []);
        await verifyImplementContract(vault, []);
    }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});