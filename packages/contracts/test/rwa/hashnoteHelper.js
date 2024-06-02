const { ethers, network, upgrades } = require("hardhat")
const helpers = require("@nomicfoundation/hardhat-toolbox/network-helpers")
const { expect } = require("chai")
const { toEther, fromEther } = require("../helper")

const USYC_PROXY = "0x136471a34f6ef19fE571EFFC1CA711fdb8E49f2b"
const STABLE_PROXY = "0x6c3ea9036406852006290770BEdFcAbA0e23A0e8"
const ORACLE_PROXY = "0x4c48bcb2160F8e0aDbf9D4F3B034f1e36d1f8b3e"
const TELLER_PROXY = "0x0a5EA26fdD38CF2Acb06Dc64198374C337879DAb"

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