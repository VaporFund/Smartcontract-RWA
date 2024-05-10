const { ethers, upgrades } = require("hardhat");

const address = "0xA399C8215c7Ea8104bf3e1182762a772F46B8F80"; // proxy token address testnet

async function main() {
    const VaultStakingBSC = await ethers.getContractFactory("MultiSigController");
    const [admin] = await ethers.getSigners()
    console.log("admin: ", admin.address)
    const vaultProxy = await upgrades.upgradeProxy(address, VaultStakingBSC);
    const vaultProxyAddress = await vaultProxy.target;
    const vaultAddress = await upgrades.erc1967.getImplementationAddress(vaultProxyAddress);
    const contractAddress = {
        vaultProxyAddress: vaultProxyAddress,
        vaultAddress: vaultAddress,
    };
    console.table(contractAddress);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});