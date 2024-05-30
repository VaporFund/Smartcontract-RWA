const { ethers, upgrades } = require("hardhat")
const { expect } = require("chai")
const { toEther, fromEther } = require("../helper")

describe("#vault", () => {

    let controller
    let vault

    let nonRebaseToken
    let rebaseToken

    let alice
    let bob
    let charlie
    let dave

    before(async() => {

        [alice, bob, charlie, dave] = await ethers.getSigners()

        const MultiSigController = await ethers.getContractFactory("MultiSigController")
        const Vault = await ethers.getContractFactory("Vault")
        const MockERC20 = await ethers.getContractFactory("MockERC20")
        const MockRToken = await ethers.getContractFactory("MockRToken")

        // controller = await MultiSigController.deploy([alice.address, bob.address, charlie.address, dave.address], 2)
        controller = await upgrades.deployProxy(MultiSigController, [
            [alice.address, bob.address, charlie.address, dave.address], 2
        ]);
        // vault = await Vault.deploy(1, controller.target)
        vault = await upgrades.deployProxy(Vault, [1, controller.target]);


        // deploy tokens
        nonRebaseToken = await MockERC20.deploy("Non-Rebase Token", "NON-REBASE", 18)
        rebaseToken = await MockRToken.deploy()

    })

    it("should deposit/withdraw native tokens from/to the vault success", async function() {

        // add supported contract
        await controller.connect(alice).addContract(vault.target)

        // deposit 10 ETH
        await vault.connect(alice).depositWithETH({ value: toEther(10) })

        // request a withdrawal
        await vault.connect(alice).requestWithdraw(
            "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
            toEther(10),
            dave.address
        )

        const request = await controller.getRequest(0)
        expect(request["contractAddress"]).to.equal(vault.target)
        expect(request["executed"]).to.false

        // signing
        await controller.connect(alice).confirmRequest(0)
        await controller.connect(bob).confirmRequest(0)

        // checking
        const beforeBalance = await ethers.provider.getBalance(dave.address)

        await controller.connect(charlie).executeRequest(0)

        const afterBalance = await ethers.provider.getBalance(dave.address)
        expect(afterBalance - beforeBalance).to.equal(toEther(10))

    })

    it("should deposit/withdraw non-rebase tokens from/to the vault success", async function() {

        // mint and deposit 10,000 NON-REBASE
        await nonRebaseToken.connect(alice).mint(toEther(10000))
        await nonRebaseToken.connect(alice).approve(vault.target, ethers.MaxUint256)

        await vault.connect(alice).depositWithERC20(nonRebaseToken.target, toEther(10000))

        // submit a request
        await vault.connect(alice).requestWithdraw(
            nonRebaseToken.target,
            toEther(10000),
            dave.address
        )

        // signing
        await controller.connect(alice).confirmRequest(1)
        await controller.connect(bob).confirmRequest(1)

        // withdrawing
        await controller.connect(charlie).executeRequest(1)

        // checking
        expect(await nonRebaseToken.balanceOf(dave.address)).to.equal(toEther(10000))

    })

    it("should deposit/withdraw rebase tokens from/to the vault success", async function() {

        // mint and deposit 100 REBASE
        await rebaseToken.connect(alice).mint({ value: toEther(100) })
        await rebaseToken.connect(alice).approve(vault.target, ethers.MaxUint256)

        await vault.connect(alice).depositWithERC20(rebaseToken.target, toEther(100))

        // submit a request
        await vault.connect(alice).requestWithdraw(
            rebaseToken.target,
            toEther(100),
            dave.address
        )

        // signing
        await controller.connect(alice).confirmRequest(2)
        await controller.connect(bob).confirmRequest(2)

        await rebaseToken.rebase(toEther(10))

        // withdrawing
        await controller.connect(charlie).executeRequest(2)

        // checking
        expect(fromEther(await rebaseToken.balanceOf(dave.address))).to.be.closeTo(100, 0.1)
            // some rewards still remain in the contract after rebasing
        expect(fromEther(await rebaseToken.balanceOf(vault.target))).to.be.closeTo(10, 0.1)

    })

})