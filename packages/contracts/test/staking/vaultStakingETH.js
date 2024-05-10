const { ethers, upgrades } = require("hardhat")
const { expect } = require("chai")
const { toEther, fromEther } = require("../helper")


const EETH_PROXY = "0x35fa164735182de50811e8e2e824cfb9b6118ac2"
const LIQUIDITY_POOL_PROXY = "0x308861a430be4cce5502d0a12724771fc6daf216"
const NFT_PROXY = "0x7d5706f6ef3F89B3951E23e557CDFBC3239D4E2c"


describe("#vault-staking", () => {
    let controller
    let vault
    let forwarder

    let operator
    let bob
    let charlie
    let dave
    let swap

    let etherfi_lp
    let etherfi_eeth

    before(async() => {

        [operator, bob, charlie, dave, swap] = await ethers.getSigners()

        const MultiSigController = await ethers.getContractFactory("MultiSigController")
        const VaultStaking = await ethers.getContractFactory("VaultStakingETH")
        const Forwarder = await ethers.getContractFactory("Forwarder")


        //deploy controller
        controller = await upgrades.deployProxy(MultiSigController, [
            [operator.address, bob.address, charlie.address, dave.address], 2
        ]);

        //deploy vault
        vault = await upgrades.deployProxy(VaultStaking, [1, controller.target]);

        //set manager for vault
        await controller.connect(operator).addContract(vault.target)


        // create etherfi's contract instances on forked mainnet
        let eethAddress = await upgrades.erc1967.getImplementationAddress(EETH_PROXY)
        let eethV1 = await ethers.getContractAt("IeETH", eethAddress)
        etherfi_eeth = await eethV1.attach(EETH_PROXY);

        let lpAddress = await upgrades.erc1967.getImplementationAddress(LIQUIDITY_POOL_PROXY);
        let lpV1 = await ethers.getContractAt("ILiquidityPool", lpAddress)
        etherfi_lp = await lpV1.attach(LIQUIDITY_POOL_PROXY)

        // create forwarder
        forwarder = await upgrades.deployProxy(Forwarder, [
            controller.target, vault.target
        ]);
        await controller.addContract(forwarder.target)
        await forwarder.register(1, etherfi_lp.target, EETH_PROXY, NFT_PROXY)
        await vault.setForwarder(forwarder.target)

    })

    it("should operator deposit successful", async function() {
        await vault.connect(operator).depositWithETH({ value: toEther(1.1) })

        // request stake
        await forwarder.requestStake(1, "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE", toEther(1.1))

        // signing
        await controller.connect(operator).confirmRequest(0)
        await controller.connect(bob).confirmRequest(0)
        await controller.connect(charlie).executeRequest(0)

        const totalClaimOf = await vault.getTotalClaimOf(1);
        expect(fromEther(totalClaimOf)).to.be.closeTo(1.1, 0.1)

    })

    it("should operator request withdraw successful", async function() {
        const currentRequestId = await controller.getRequestCount();
        // request stake
        await forwarder.requestWithdraw(1, toEther(0.8))

        // signing
        await controller.connect(operator).confirmRequest(currentRequestId)
        await controller.connect(bob).confirmRequest(currentRequestId)
        await controller.connect(charlie).executeRequest(currentRequestId)

        const totalClaimOf = await vault.getTotalClaimOf(1);
        expect(fromEther(totalClaimOf)).to.be.closeTo(0.3, 0.01)

    })
    it("should operator request withdraw successful", async function() {
        const currentRequestId = await controller.getRequestCount();

        // request stake
        await forwarder.requestWithdraw(1, toEther(0.1))

        // signing
        await controller.connect(operator).confirmRequest(currentRequestId)
        await controller.connect(bob).confirmRequest(currentRequestId)
        await controller.connect(charlie).executeRequest(currentRequestId)

        const txClaimOf = await vault.getTotalClaimOf(1);
        expect(fromEther(txClaimOf)).to.be.closeTo(0.2, 0.01)


    })
    it("should operator claim successful", async function() {
        const currentRequestId = await controller.getRequestCount();
        const nftPending = await vault.getPendingClaims(EETH_PROXY)
        console.log(nftPending)

        // request stake
        await forwarder.requestClaimWithdraw(1, nftPending[0])

        // signing
        await controller.connect(operator).confirmRequest(currentRequestId)
        await controller.connect(bob).confirmRequest(currentRequestId)
        await controller.connect(charlie).executeRequest(currentRequestId)

        const totalClaimOf = await vault.getTotalClaimOf(1, 1);
        console.log(totalClaimOf)

        //TODO: need from etherfi

        // expect(fromEther(totalClaimOf)).to.be.closeTo(1.1, 0.1)

    })

    it("should withdraw fund successful", async function() {
        // Deposit ETH to the vault
        await vault.connect(operator).depositWithETH({ value: toEther(1.1) });

        // Check the initial ETH balances of the vault and swap
        const initialVaultBalance = await ethers.provider.getBalance(vault.target);
        const initialSwapBalance = await ethers.provider.getBalance(swap.address);

        // Request withdrawal of ETH
        const currentRequestId = await controller.getRequestCount();
        await vault.requestWithdrawFund("0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE", toEther(1), swap.address);

        // Confirm and execute the withdrawal request
        await controller.connect(operator).confirmRequest(currentRequestId);
        await controller.connect(bob).confirmRequest(currentRequestId);
        await controller.connect(charlie).executeRequest(currentRequestId);

        // Check the ETH balances of the vault and swap after withdrawal
        const vaultBalanceAfterWithdraw = await ethers.provider.getBalance(vault.target);
        const swapBalanceAfterWithdraw = await ethers.provider.getBalance(swap.address);

        // Assert that the balances have changed correctly
        expect(BigInt(initialVaultBalance) - BigInt(toEther(1))).to.equal(BigInt(vaultBalanceAfterWithdraw));
        expect(BigInt(initialSwapBalance) + BigInt(toEther(1))).to.equal(BigInt(swapBalanceAfterWithdraw));
    });

})