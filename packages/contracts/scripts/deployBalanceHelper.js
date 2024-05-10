const { ethers, upgrades } = require("hardhat");
const { verifyContract } = require("./verifyUtils");

async function deployContracts() {
    const [operator] = await ethers.getSigners()

    const BalanceHelper = await ethers.getContractFactory("BalanceHelper")
    const balanceHelper = await BalanceHelper.deploy(1000);
    balanceHelper.waitForDeployment();
    console.table({ balanceHelperAddress: balanceHelper.target });

    for (let i = 0; i < 3; i++) {
        await verifyContract(balanceHelper, [1000]);
    }

}
deployContracts().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});