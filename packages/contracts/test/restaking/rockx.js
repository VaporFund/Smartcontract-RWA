const { ethers, network, upgrades } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-toolbox/network-helpers")
const { expect } = require("chai")
const { toEther, fromEther } = require("../helper")

const ROCKX_ETH_PROXY = "0xF1376bceF0f78459C0Ed0ba5ddce976F1ddF51F4"

const ROCKX_STAKING_PROXY = "0x4beFa2aA9c305238AA3E0b5D17eB20C045269E9d"

describe("#rockx", () => {

    let rockxStaking
    let rockxEth

    let accounts

    before(async () => {
        accounts = await ethers.getSigners()
    
        let rockxEthAddress = await upgrades.erc1967.getImplementationAddress(ROCKX_ETH_PROXY)
        let rockxEthV1 = await ethers.getContractAt("RockXETH", rockxEthAddress)
        rockxEth = await rockxEthV1.attach(ROCKX_ETH_PROXY);

        let rockxStakingAddress = await upgrades.erc1967.getImplementationAddress(ROCKX_STAKING_PROXY);
        let rockxStakingV1 = await ethers.getContractAt("RockXStaking", rockxStakingAddress)
        rockxStaking = await rockxStakingV1.attach(ROCKX_STAKING_PROXY)

    })

    it("should deposit ETH success", async function () {
        let alice = accounts[1]
        let bob = accounts[2]

        await rockxStaking.connect(alice).mint(0, ethers.MaxUint256, { value: toEther(1) })
        await rockxStaking.connect(bob).mint(0, ethers.MaxUint256, { value: toEther(40) })
    
        let balanceA = await rockxEth.balanceOf(alice.address)
        let balanceB = await rockxEth.balanceOf(bob.address)

        expect( fromEther( balanceA)).to.be.closeTo(1, 0.1)
        expect( fromEther( balanceB)).to.be.closeTo(40, 4)
    })

    it("should redeem xETH success", async function () {
        let bob = accounts[2]

        await rockxEth.connect(bob).approve( rockxStaking.target, ethers.MaxUint256 )
        await rockxStaking.connect(bob).redeemFromValidators( toEther(32), ethers.MaxUint256, ethers.MaxUint256)
    })

})