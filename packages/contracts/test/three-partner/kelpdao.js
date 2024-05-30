
const { ethers, network, upgrades } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-toolbox/network-helpers")
const { expect } = require("chai")
const { toEther, fromEther } = require("../helper")

const LRT_DEPOSIT_POOL_PROXY = "0x036676389e48133B63a802f8635AD39E752D375D"

const RSETH_PROXY = "0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7"

const REF_ID = "3ad3da4ea9725993d12920fd3d20882e26d35446c12d219290d4be31b0b1cddb"

const ETH_TOKEN = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";

describe("#kelpdao", () => {

    let depositPool
    let rseth

    let accounts

    before(async () => {
        
        accounts = await ethers.getSigners()

        let depositPoolAddress = await upgrades.erc1967.getImplementationAddress(LRT_DEPOSIT_POOL_PROXY)
        let depositPoolV1 = await ethers.getContractAt("ILRTDepositPool", depositPoolAddress)
        depositPool = await depositPoolV1.attach(LRT_DEPOSIT_POOL_PROXY);
    
        let rsethAddress = await upgrades.erc1967.getImplementationAddress(RSETH_PROXY)
        let rsethV1 = await ethers.getContractAt("IRSETH", rsethAddress)
        rseth = await rsethV1.attach(RSETH_PROXY);

    })

    it("should deposit ETH for rsETH success", async function () {
        let alice = accounts[1]

        // deposit 1 ETH
        let minimunAmountOfRSETHToReceive = await depositPool.getRsETHAmountToMint(ETH_TOKEN, toEther(1));
        await depositPool.connect(alice).depositETH(minimunAmountOfRSETHToReceive, REF_ID, { value: toEther(1) })
        
        // checking balance
        expect( fromEther( await rseth.balanceOf(alice.address) ) ).to.be.closeTo(1, 0.1)
    })

    // KelpDAO is not available for withdrawal


})