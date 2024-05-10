// const { ethers } = require("hardhat")
// const { expect } = require("chai")

// describe("#erc404", () => {

//     let pandora
//     let accounts

//     before(async () => {

//         accounts = await ethers.getSigners();

//         // deploy contract
//         const Pandora = await ethers.getContractFactory("Pandora")
//         const PandoraMarket = await ethers.getContractFactory("PandoraMarket")

//         pandora = await Pandora.deploy(accounts[0])
//         market = await PandoraMarket.deploy(pandora.target)

//     })

//     it("should fetch metadata success", async function () {
//         expect(await pandora.name()).to.equal("Pandora")
//         expect(await pandora.symbol()).to.equal("PANDORA")
//         expect(await pandora.decimals()).to.equal(18n)
//         expect(await pandora.totalSupply()).to.equal(10000000000000000000000n)
//     })

//     it("should mint NFTs success", async function () {
        
//         let alice = accounts[1]
//         let bob = accounts[2]

//         // add liquidity to the marketplace
//         await pandora.setWhitelist(accounts[0].address, true)
//         await pandora.setWhitelist(market.target, true)

//         await pandora.approve(market.target, 10000000000000000000000n);
//         await market.addLiquidity(10000000000000000000000n)

//         // get the ERC-721 from the marketplace
//         await market.connect(alice).buy(1) // 1 unit
//         await market.connect(bob).buy(2) // 2 units
        
//         let totalNFT = await pandora.minted()
//         expect(totalNFT).to.equal(3)

//         // verifying the ownership
//         expect(await pandora.ownerOf(1)).to.equal(alice.address)
//         expect(await pandora.ownerOf(2)).to.equal(bob.address)
//         expect(await pandora.ownerOf(3)).to.equal(bob.address)

//         // checking remaining ERC-20
//         let remainingFT = await pandora.balanceOf(market.target)
//         expect(remainingFT).to.equal(9997000000000000000000n)
//     })

//     it("should transfer NFTs success", async function () {
        
//         let alice = accounts[1]
//         let bob = accounts[2]
//         let charlie = accounts[3]

//         // send all them to charlie
//         await pandora.connect(alice).safeTransferFrom(alice.address, charlie.address, 1)
//         await pandora.connect(bob).safeTransferFrom(bob.address, charlie.address, 2)
//         await pandora.connect(bob).safeTransferFrom(bob.address, charlie.address, 3)

//         // verifying the ownership
//         expect(await pandora.ownerOf(1)).to.equal(charlie.address)
//         expect(await pandora.ownerOf(2)).to.equal(charlie.address)
//         expect(await pandora.ownerOf(3)).to.equal(charlie.address)
//     })

// })