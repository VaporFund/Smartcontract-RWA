const { ethers, upgrades } = require("hardhat");
const { StandardMerkleTree } = require("@openzeppelin/merkle-tree"); // Change import to require
const { verifyImplementContract, verifyContract } = require("./verifyUtils");

async function deployContracts() {
    const [operator, bob, charlie, dave] = await ethers.getSigners()

    const MultiSigController = await ethers.getContractFactory("MultiSigController")
    const VaultStakingBSC = await ethers.getContractFactory("VaultStakingBSC")
    const VaultManager = await ethers.getContractFactory("VaultManager")
    const WhitelistManager = await ethers.getContractFactory("WhitelistManager");
    const TokenFactory = await ethers.getContractFactory("TokenFactory");


    const controllerBSCAddress = "0x9af518cD60747512E983Cc04c346Ec44596D24C2"

    //deploy vault manager
    const vaultManager = await upgrades.deployProxy(VaultManager, [controllerBSCAddress]);
    await vaultManager.waitForDeployment();


    const addressB = {
        controllerBSCAddress: controllerBSCAddress,
        vaultManagerAddress: vaultManager.target,
    }
    console.table(addressB);

    for (let i = 0; i < 3; i++) {
        // verify for vault manage
        await verifyContract(vaultManager, [
            controllerBSCAddress
        ]);
        await verifyImplementContract(vaultManager, []);
    }

}
deployContracts().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});