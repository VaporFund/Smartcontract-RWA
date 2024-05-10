const { ethers, upgrades } = require("hardhat");
const { verifyImplementContract, verifyContract } = require("../../verifyUtils");

async function deployContracts() {
    const [operator, bob, charlie, dave, worker] = await ethers.getSigners()
    console.log({ operatorAddress: operator.address })
    const WhitelistManager = await ethers.getContractFactory("WhitelistManager");


    //load from address
    // const whitelistManager = await ethers.getContractAt("WhitelistManager", "0xb4f7b648be3158421bd73846c7cd0093674fe8d5");

    //deploy whitelist
    const whitelistManager = await WhitelistManager.deploy();
    await whitelistManager.waitForDeployment()
    console.log({ whitelistManagerAddress: whitelistManager.target })


    for (let i = 0; i < 3; i++) {
        //verify whitelist manage
        await verifyContract(whitelistManager, []);
    }

}
deployContracts().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});