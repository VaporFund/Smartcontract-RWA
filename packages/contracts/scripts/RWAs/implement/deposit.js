const { ethers, upgrades } = require("hardhat");
const { verifyImplementContract, verifyContract } = require("../../verifyUtils");
const { toStable, toEther } = require("../../../test/helper");

// const STABLE_PROXY = "0xCaC524BcA292aaade2DF8A05cC58F0a65B1B3bB9" // sepolia
// const vpUSYC = "0xbcea3f410688973ad0a6d4185eb7f93bd47a2190" // sepolia
// const VAULT = "0x38efCc435b677d8c68bC48A4F2EDFDA1eD2917F3" // sepolia

const STABLE_PROXY = "0x6c3ea9036406852006290770BEdFcAbA0e23A0e8" // mainnet
const vpUSYC = "0x0e0cD306EC48CC61CA582a80c63806058920961C" // mainnet
const VAULT = "0xdc9C2e95811b183752A1c5893182904d4fa7E781" // mainnet

const WETH9_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"

const VAULT_RWA_SPENDER_APPROVE_ROLE = "0x0e6e592b6b5bc62e7d850078c0c85c87d354122e248b1884918dacf86c7996da"
const UNISWAP_ROUTER = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45"
async function deployContracts() {
    const [operator] = await ethers.getSigners()
    console.log({ operatorAddress: operator.address })

    //load from address
    const vault = await ethers.getContractAt("VaultRwa", VAULT);
    const stableToken = await ethers.getContractAt("IPYUSDImplementation", STABLE_PROXY);

    // //approve spender
    // await stableToken.approve(vault.target, ethers.MaxUint256);

    // buy at stable token
    // await vault.deposit("0x8009abf3c3e0e1fcc6d14d8e741e6e96ed2d3daf64c64827d3d03190ec078c79", [], vpUSYC, [
    //     { tokenAddress: WETH9_ADDRESS, poolFee: 3000 },
    //     { tokenAddress: USDC, poolFee: 3000 }
    // ], toStable(5), 0, "0x9df690ab1cca8dcb337c418f3085e26d9c3d8e43ad581076810868dceb8c6f96071e12cf554510c4e85fcb8c6ad0f1c5320a4f024f57c350080ece2baa1d28951c", 1717906843350, { value: toEther(0.0017) });

    // //load from address, whitelist manual
    // const whitelistManager = await ethers.getContractAt("WhitelistManager", "0x97E94C785F94DE64e66745811F1bb7b0193f5f80");
    // await whitelistManager.setStatusDisableWhitelist(true)

    // await vault.approveRequestWithdraw([1]);

    // const nftAddresss = await vault.withdrawNft()
    // nft = await ethers.getContractAt("MockERC721", nftAddresss);
    // await nft.approve(vault.target, 1);

    // await vault.connect(operator).approve(stableToken.target, UNISWAP_ROUTER, ethers.MaxUint256)

    await vault.withdraw(1, [{ tokenAddress: STABLE_PROXY, poolFee: 3000 }, ], USDC, 0);

    // const roleManage = await ethers.getContractAt("RoleManage", "0xA62C5631A7e6F88d0E1F60ca6fdfE8DF2aD249c8");
    // await roleManage.setRoleAddress(VAULT_RWA_SPENDER_APPROVE_ROLE, UNISWAP_ROUTER)



}
deployContracts().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});