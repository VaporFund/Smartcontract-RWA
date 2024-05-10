const { ethers, network, upgrades } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-toolbox/network-helpers")
const { expect } = require("chai")
const { toEther, fromEther } = require("../helper")

const USYC_PROXY = "0x38D3A3f8717F4DB1CcB4Ad7D8C755919440848A3"
const STABLE_PROXY = "0xCaC524BcA292aaade2DF8A05cC58F0a65B1B3bB9"
const ORACLE_PROXY = "0x35b96d80C72f873bACc44A1fACfb1f5fac064f1a"
const TELLER_PROXY = "0x8C5d21F2DA253a117E8B89108be8FE781583C1dF"

describe("#hashnote-helper", () => {

    let oracle
    let hashnoteHelper

    let accounts

    before(async() => {
        accounts = await ethers.getSigners()
        oracle = await ethers.getContractAt("IYieldTokenOracle", ORACLE_PROXY)
        const hashnoteHelperFactory = await ethers.getContractFactory("HashnoteHelper")
        hashnoteHelper = await hashnoteHelperFactory.deploy(USYC_PROXY, STABLE_PROXY, ORACLE_PROXY, TELLER_PROXY);
    })

    it("should fetch latest round success", async function() {
        const latestRoundDetails = await oracle.latestRoundDetails()
        expect(latestRoundDetails.length).to.equal(5)
    })
    it("should return buy preview success", async function() {
        const buyPreview = await hashnoteHelper.buyPreview(1041420);
        expect(typeof buyPreview).to.equal("object");
    })
    it("should return sell preview success", async function() {
        const sellPreview = await hashnoteHelper.sellPreview(1000000);
        expect(typeof sellPreview).to.equal("object");
    })
    it("should return total stoken success", async function() {
        const stokenBalance = await hashnoteHelper.getTotalStableTokenByYieldToken("0x2852eBc6199288b4686009067f4b586E5A88c9F6");
        expect(typeof stokenBalance).to.equal("bigint");
    })

    it("should return sell preview success", async function() {
        const sellPreview = await hashnoteHelper.calculationPercentInterestPerRound();
        expect(typeof sellPreview[0]).to.equal("bigint");
        expect(typeof sellPreview[1]).to.equal("bigint");

    })
})