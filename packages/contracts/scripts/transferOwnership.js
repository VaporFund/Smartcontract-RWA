const { ethers, upgrades } = require("hardhat");
const { verifyImplementContract, verifyContract } = require("./verifyUtils");

async function deployContracts() {
    const [operator, bob, charlie, dave, worker] = await ethers.getSigners()
    console.log({ operatorAddress: operator.address })

    //load from address
    const contract = await ethers.getContractAt("@openzeppelin/contracts/access/Ownable.sol:Ownable", "0x4e48312148141fa4ABBEb2806490058c86AA8b95");
    await contract.transferOwnership("0x75AC2d34f0c4655A25D341B41a938225246199FC")


}
deployContracts().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});