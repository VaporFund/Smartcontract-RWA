
const { ethers, network, upgrades } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-toolbox/network-helpers")
const { expect } = require("chai")
const { toEther, fromEther } = require("../helper")

const LRT_DEPOSIT_POOL_PROXY = "0xA479582c8b64533102F6F528774C536e354B8d32"

const PRIMEETH_PROXY = "0x6ef3D766Dfe02Dc4bF04aAe9122EB9A0Ded25615"

const REF_ID = "Origin"

const ETH_TOKEN = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee";

describe("#primestaked", () => {

    let depositPool
    let primeeth

    let accounts

    before(async () => {
        
        accounts = await ethers.getSigners()

        let depositPoolAddress = await upgrades.erc1967.getImplementationAddress(LRT_DEPOSIT_POOL_PROXY)
        let depositPoolV1 = await ethers.getContractAt("IPrimeLRTDepositPool", depositPoolAddress)
        depositPool = await depositPoolV1.attach(LRT_DEPOSIT_POOL_PROXY);
    
        let primeethAddress = await upgrades.erc1967.getImplementationAddress(PRIMEETH_PROXY)
        let primeethV1 = await ethers.getContractAt("IPrimeETH", primeethAddress)
        primeeth = await primeethV1.attach(PRIMEETH_PROXY);

    })

    it("should deposit ETH for primeETH success", async function () {
        let alice = accounts[1]

        // FIXME: HardhatEthersProvider.resolveName Error

        // deposit 1 ETH
        // let minAmount = await depositPool.getMintAmount(ETH_TOKEN, toEther(1));
        // await depositPool.connect(alice).depositAsset(ETH_TOKEN, toEther(1) , minAmount, REF_ID, { value: toEther(1) })
        
        // // checking balance
        // expect( fromEther( await primeeth.balanceOf(alice.address))).to.be.closeTo(1, 0.1)
    })

    // same to KelpDAO


})