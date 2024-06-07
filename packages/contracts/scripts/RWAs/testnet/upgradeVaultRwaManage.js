const { ethers, upgrades } = require("hardhat");
const { verifyImplementContract, verifyContract } = require("../../verifyUtils");

const vaultRwaManagerAddress = "0x08f7492A005a772c09178Aec39171440277b6003"; // proxy address vault

async function main() {
    const VaultManager = await ethers.getContractFactory("VaultRwaManager")

    //for try deploy
    const vaultManager = await ethers.getContractAt("VaultRwaManager", vaultRwaManagerAddress);

    const [admin] = await ethers.getSigners()
    console.log("admin: ", admin.address)

    const vaultManagerProxy = await upgrades.upgradeProxy(vaultManager, VaultManager);
    const vaultManagerProxyAddress = await vaultManagerProxy.target;
    const vaultRwaManagerAddressImplement = await upgrades.erc1967.getImplementationAddress(vaultManagerProxyAddress);


    const contractAddress = {
        vaultRwaManagerProxyAddress: vaultManagerProxyAddress,
        vaultRwaManagerAddressImplement: vaultRwaManagerAddressImplement,
    };
    console.table(contractAddress);

    for (let i = 0; i < 3; i++) {
        //verify vault rwa
        await verifyContract(vaultManager, []);
        await verifyImplementContract(vaultManager, []);
    }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});