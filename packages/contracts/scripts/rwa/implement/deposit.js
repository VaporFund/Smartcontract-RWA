const { ethers, upgrades } = require("hardhat");
const { verifyImplementContract, verifyContract } = require("../../verifyUtils");
const { toStable } = require("../../../test/helper");

const USYC_PROXY = "0x38D3A3f8717F4DB1CcB4Ad7D8C755919440848A3"
const STABLE_PROXY = "0xCaC524BcA292aaade2DF8A05cC58F0a65B1B3bB9"
const ORACLE_PROXY = "0x35b96d80C72f873bACc44A1fACfb1f5fac064f1a"
const TELLER_PROXY = "0x8C5d21F2DA253a117E8B89108be8FE781583C1dF"
const UNISWAP_ROUTER = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45" // router not support sophia

async function deployContracts() {
    const [operator] = await ethers.getSigners()
    console.log({ operatorAddress: operator.address })

    //load from address
    const vault = await ethers.getContractAt("VaultRwa", "0x38efCc435b677d8c68bC48A4F2EDFDA1eD2917F3");
    const stableToken = await ethers.getContractAt("IPYUSDImplementation", STABLE_PROXY);

    //approve spender
    await stableToken.approve(vault.target, ethers.MaxUint256);

    // buy at stable token
    await vault.deposit("0x8009abf3c3e0e1fcc6d14d8e741e6e96ed2d3daf64c64827d3d03190ec078c79", [], "0xbcea3f410688973ad0a6d4185eb7f93bd47a2190", [], toStable(5), 0, "0x9df690ab1cca8dcb337c418f3085e26d9c3d8e43ad581076810868dceb8c6f96071e12cf554510c4e85fcb8c6ad0f1c5320a4f024f57c350080ece2baa1d28951c", 1717906843350);
}
deployContracts().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});