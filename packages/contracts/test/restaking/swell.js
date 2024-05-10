const { ethers, network, upgrades } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-toolbox/network-helpers")
const { expect } = require("chai")
const { toEther, fromEther } = require("../helper")

const RSWETH_PROXY = "0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0"

describe("#swell", () => {

    let rsweth

    let accounts

    before(async () => {
        accounts = await ethers.getSigners()

        let rswethAddress = await upgrades.erc1967.getImplementationAddress(RSWETH_PROXY)
        let rswethV1 = await ethers.getContractAt("IrswETH", rswethAddress)
        rsweth = await rswethV1.attach(RSWETH_PROXY);
    })

    it("should deposit ETH success", async function () {
        let alice = accounts[1]

        await rsweth.connect(alice).deposit({ value: toEther(1) })

        const balance = await rsweth.balanceOf(alice.address)
        expect(fromEther(balance)).to.be.closeTo(1, 0.1)
    })

    // not available for withdrawal

})