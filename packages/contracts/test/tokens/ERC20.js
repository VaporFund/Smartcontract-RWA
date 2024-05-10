// const { ethers, network } = require("hardhat")
// const { expect } = require("chai")

// const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"; // USDC contract on mainnet

// describe("#erc20", () => {

//     let usdc

//     before(async () => {
//         usdc = await ethers.getContractAt("IERC20Metadata", USDC);
//     })

//     it("should fetch ERC-20 metadata on-chain success", async function () {
//        expect(await usdc.name()).to.equal("USD Coin")
//        expect(await usdc.symbol()).to.equal("USDC")
//        expect(await usdc.decimals()).to.equal(6) 
//     })

// })