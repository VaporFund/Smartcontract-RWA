const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");

describe("#oracle", () => {
    let oracle;
    let owner;
    let confirmer1;
    let confirmer2;
    let nonConfirmer;
    const tokenA = "0xf25484650484de3d554fb0b7125e7696efa4ab99";
    const tokenB = "0xf25484650484de3d554fb0b7125e7696efa4ab99"

    beforeEach(async() => {
        [owner, confirmer1, confirmer2, nonConfirmer] = await ethers.getSigners();
        const Oracle = await ethers.getContractFactory("Oracle");
        oracle = await upgrades.deployProxy(Oracle, []);
        await oracle.waitForDeployment();
        await oracle.setIsConfirmer(confirmer1.address, true);
        await oracle.setIsConfirmer(confirmer2.address, true);
    });

    it("should initialize with correct update limit and number of confirmations required", async() => {
        const updateLimit = await oracle.updateLimit();
        const numConfirmationsRequired = await oracle.numConfirmationsRequired();

        expect(updateLimit).to.equal(7200); // 2 hours in seconds
        expect(numConfirmationsRequired).to.equal(1);
    });

    it("should allow owner to set update limit", async() => {
        const newLimit = 3600; // 1 hour in seconds
        await oracle.connect(owner).setUpdateLimit(newLimit);
        const updatedLimit = await oracle.updateLimit();

        expect(updatedLimit).to.equal(newLimit);
    });

    it("should allow owner to set number of confirmations required", async() => {
        const newNumConfirmationsRequired = 2;
        await oracle.connect(owner).setNumConfirmationsRequired(newNumConfirmationsRequired);
        const updatedNumConfirmationsRequired = await oracle.numConfirmationsRequired();

        expect(updatedNumConfirmationsRequired).to.equal(newNumConfirmationsRequired);
    });

    it("should allow confirmer to submit data", async() => {
        await oracle.connect(confirmer1).submitData(
            tokenA,
            tokenB,
            100,
            200,
            300
        );

        const submitId = 0;
        const confirmers = await oracle.getConfirmers(submitId);
        expect(confirmers.length).to.equal(1);
    });

    it("should allow confirmer to confirm submission", async() => {
        await oracle.connect(confirmer1).submitData(
            tokenA,
            tokenB,
            100,
            200,
            300
        );

        const submitId = 0;
        await oracle.connect(confirmer2).confirmSubmit(submitId);

        const confirmers = await oracle.getConfirmers(submitId);
        expect(confirmers.length).to.equal(2);
    });

    it("should update token pair data when confirmed by required number of confirmers", async() => {
        await oracle.connect(confirmer1).submitData(
            tokenA,
            tokenB,
            100,
            200,
            300
        );

        const submitId = 0;
        await oracle.connect(confirmer2).confirmSubmit(submitId);
        const data = await oracle.getData(tokenA, tokenB);

        expect(data[0]).to.equal(BigInt(100)); // Check apr
        expect(data[1]).to.equal(BigInt(200)); // Check totalShare
        expect(data[2]).to.equal(BigInt(300)); // Check totalValueOfLp
    });

    it("should revert when non-confirmer tries to submit data", async() => {
        await expect(
            oracle.connect(nonConfirmer).submitData(
                tokenA,
                tokenB,
                100,
                200,
                300
            )
        ).to.be.revertedWith("Only confirmer");
    });

    it("should revert when non-confirmer tries to confirm submission", async() => {
        await oracle.connect(confirmer1).submitData(
            tokenA,
            tokenB,
            100,
            200,
            300
        );

        const submitId = 0;

        await expect(
            oracle.connect(nonConfirmer).confirmSubmit(submitId)
        ).to.be.revertedWith("Only confirmer");
    });
});