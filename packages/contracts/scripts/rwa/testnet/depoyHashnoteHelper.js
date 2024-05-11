const { ethers, upgrades } = require("hardhat");
const { verifyImplementContract, verifyContract } = require("../../verifyUtils");

const USYC_PROXY = "0x38D3A3f8717F4DB1CcB4Ad7D8C755919440848A3"
const STABLE_PROXY = "0xCaC524BcA292aaade2DF8A05cC58F0a65B1B3bB9"
const ORACLE_PROXY = "0x35b96d80C72f873bACc44A1fACfb1f5fac064f1a"
const TELLER_PROXY = "0x8C5d21F2DA253a117E8B89108be8FE781583C1dF"

async function deployContracts() {
    const [operator] = await ethers.getSigners()
    console.log({ operatorAddress: operator.address })
    const HashnoteHelper = await ethers.getContractFactory("HashnoteHelper");

    //load from address
    const hashnoteHelper = await ethers.getContractAt("HashnoteHelper", "0x8Daa36c26A8c350E450B139eB06EB2789a113440");

    // //deploy hashnote helper
    // const hashnoteHelper = await HashnoteHelper.deploy(USYC_PROXY, STABLE_PROXY, ORACLE_PROXY, TELLER_PROXY);
    // await hashnoteHelper.waitForDeployment()
    // console.log({ hashnoteHelperAddress: hashnoteHelper.target })


    for (let i = 0; i < 3; i++) {
        //verify whitelist manage
        await verifyContract(hashnoteHelper, [USYC_PROXY, STABLE_PROXY, ORACLE_PROXY, TELLER_PROXY]);
    }

}
deployContracts().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});