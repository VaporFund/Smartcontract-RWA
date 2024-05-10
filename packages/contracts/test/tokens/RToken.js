const { ethers } = require("hardhat")
const { expect } = require("chai")
const { toEther } = require("../helper")


describe("#rebaseToken", () => {

    let rToken
    let alice
    let bob

    before(async () => {

        [alice, bob] = await ethers.getSigners()
        
        const MockRToken = await ethers.getContractFactory("MockRToken")
        rToken = await MockRToken.deploy()

    })

    it("should mint 1/2 rETH success", async function () {
         
        await rToken.mint({ value : toEther(1)})
        await rToken.connect(bob).mint({ value : toEther(2)})
        expect(await rToken.balanceOf(alice.address)).to.equal(toEther(1))
        expect(await rToken.balanceOf(bob.address)).to.equal(toEther(2))
        
    })

    it("should redeem rETH after rebase success", async function () {
         
        // add 0.06 ETH 
        // Alice -> 0.02 / Bob -> 0.04
        await rToken.rebase( toEther(0.06) )
        expect(await rToken.balanceOf(alice.address)).to.equal(toEther(1.02))

        await rToken.burn(alice.address, toEther(1.02))
        expect(await rToken.balanceOf(alice.address)).to.equal(0)
    })

})