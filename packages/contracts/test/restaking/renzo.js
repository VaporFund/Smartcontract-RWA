const { ethers, network, upgrades } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-toolbox/network-helpers")
const { expect } = require("chai")
const { toEther, fromEther } = require("../helper")

const RESTAKE_MANAGER_PROXY = "0x74a09653A083691711cF8215a6ab074BB4e99ef5"

const EZETH_PROXY = "0xbf5495Efe5DB9ce00f80364C8B423567e58d2110"

const REF_ID = 1210212160163292738522823961653551370142395578752n

describe("#renzo", () => {

    let restakeManager
    let ezeth

    let accounts

    before(async () => {
        accounts = await ethers.getSigners()

        let restakeManagerAddress = await upgrades.erc1967.getImplementationAddress(RESTAKE_MANAGER_PROXY)
        let restakeManagerV1 = await ethers.getContractAt("IRestakeManager", restakeManagerAddress)
        restakeManager = await restakeManagerV1.attach(RESTAKE_MANAGER_PROXY);
    
        let rsethAddress = await upgrades.erc1967.getImplementationAddress(EZETH_PROXY)
        let ezethV1 = await ethers.getContractAt("IEzEthToken", rsethAddress)
        ezeth = await ezethV1.attach(EZETH_PROXY);
    })

    it("should deposit ETH for ezETH success", async function () {
        let alice = accounts[1]

        // deposit 1 ETH
        await restakeManager.connect(alice).depositETH(REF_ID, { value: toEther(1) })

        // checking balance 
        expect( fromEther( await ezeth.balanceOf(alice.address))).to.be.closeTo(1, 0.1)
    })

    // Renzo is not available for withdrawal (has been deleted on the latest version)

})