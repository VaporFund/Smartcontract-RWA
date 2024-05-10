
const { ethers, network, upgrades } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-toolbox/network-helpers")
const { expect } = require("chai")
const { toEther, fromEther } = require("../helper")

const EETH_PROXY = "0x35fa164735182de50811e8e2e824cfb9b6118ac2"

const LIQUIDITY_POOL_PROXY = "0x308861a430be4cce5502d0a12724771fc6daf216"

// const WITHDRAW_NFT_PROXY = "0x7d5706f6ef3F89B3951E23e557CDFBC3239D4E2c"

describe("#etherfi", () => {

    let lp
    let eeth

    let accounts

    before(async () => {

        accounts = await ethers.getSigners()

        let eethAddress = await upgrades.erc1967.getImplementationAddress(EETH_PROXY)
        let eethV1 = await ethers.getContractAt("IeETH", eethAddress)
        eeth = await eethV1.attach(EETH_PROXY);

        let lpAddress = await upgrades.erc1967.getImplementationAddress(LIQUIDITY_POOL_PROXY);
        let lpV1 = await ethers.getContractAt("ILiquidityPool", lpAddress)
        lp = await lpV1.attach(LIQUIDITY_POOL_PROXY)

    })

    it("should fetch params on-chain success", async function () {
        expect( await eeth.name() ).to.equal("ether.fi ETH")
        expect( await eeth.symbol() ).to.equal("eETH")
        expect( await eeth.decimals() ).to.equal(18n)
        expect( await lp.totalValueOutOfLp()+await lp.totalValueInLp() ).to.equal(await lp.getTotalPooledEther())
    })

    it("should deposit ETH for eETH success", async function () {

        let alice = accounts[1]
        let bob = accounts[2]

        await lp.connect(alice).deposit({ value: toEther(1) })
        await lp.connect(bob).deposit({  value: toEther(2)})

        // verify balances
        expect( fromEther( await eeth.balanceOf(alice.address) ) ).to.be.closeTo(1, 0.1)
        expect( fromEther( await eeth.balanceOf(bob.address) ) ).to.be.closeTo(2, 0.1)

    })

    it("should withdraw eETH and get WithdrawRequestNFT success", async function () {
        let alice = accounts[1]

        // holding eETH for 10 days
        await helpers.mine(71760, { interval: 12 });

        await eeth.connect(alice).approve( lp.target , ethers.MaxUint256)
        
        let tx = await lp.connect(alice).requestWithdraw(alice.address, await eeth.balanceOf(alice.address))
        await tx.wait();

        let txReceipt = await ethers.provider.getTransactionReceipt(tx.hash); 
        
        // TODO: get the requestId and perform further withdrawal process


    })

})