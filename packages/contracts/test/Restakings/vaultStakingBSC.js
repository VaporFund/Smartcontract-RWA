const { ethers, upgrades } = require("hardhat")
const { expect } = require("chai")
const { toEther, fromEther } = require("../helper")
const { StandardMerkleTree } = require("@openzeppelin/merkle-tree"); // Change import to require

describe("#vault-staking-bsc", () => {

    let controller
    let vault
    let whitelistManager
    let vaultManager
    let vpeETH
    let nft
    let mockWETH // WETH on BNB

    let operator
    let bob
    let charlie
    let dave
    let swap

    let merkleTree

    before(async() => {

        [operator, bob, charlie, dave, swap] = await ethers.getSigners()

        const MultiSigController = await ethers.getContractFactory("MultiSigController")
        const VaultStaking = await ethers.getContractFactory("VaultStakingBSC")
        const MockERC20 = await ethers.getContractFactory("MockERC20")
        const VaultManager = await ethers.getContractFactory("VaultManager")
        const WhitelistManager = await ethers.getContractFactory("WhitelistManager");
        const TokenFactory = await ethers.getContractFactory("TokenFactory");

        //deploy controller
        controller = await upgrades.deployProxy(MultiSigController, [
            operator.address, [operator.address, bob.address, charlie.address, dave.address], 2
        ]);

        //deploy whitelist
        whitelistManager = await WhitelistManager.deploy();

        //deploy vault manager
        vaultManager = await upgrades.deployProxy(VaultManager, [controller.target]);

        //deploy vault
        vault = await upgrades.deployProxy(VaultStaking, [1, controller.target, whitelistManager.target, vaultManager.target]);

        //set manager for vault
        await vaultManager.setVault(vault.target);

        // deploy ERC-20 tokens
        mockWETH = await MockERC20.deploy("Mock Wrapped Ethereum", "WETH", 18)

        //deploy factory
        const factory = await TokenFactory.deploy();

        //set factory to vault manage
        await vaultManager.setTokenFactory(factory.target);

        // prefer user to whitelist
        const leaves = [operator, bob, charlie, dave].map(account => [account.address]);
        merkleTree = StandardMerkleTree.of(leaves, ["address"]);
        const merkleRoot = merkleTree.root;
        await whitelistManager.setRoot(merkleRoot, true);

        // create EETH token
        await vaultManager.createToken("Vapor Etherfi ETH", "VPEETH", 18);
        vpeETH = await ethers.getContractAt("IElasticToken", await vaultManager.bridgeTokens(0));

        // add supported contract
        await controller.connect(operator).addContract(vaultManager.target)
        await controller.connect(operator).addContract(vault.target)

        // get nft contract
        const nftAddresss = await vault.withdrawNft()
        nft = await ethers.getContractAt("MockERC721", nftAddresss);
    })
    it("should create new order success", async function() {
        // setup an order for eETH 
        await vaultManager.connect(operator).setupNewOrder(vpeETH.target, mockWETH.target)

        // checking
        expect((await vaultManager.orders(vpeETH.target)).active).to.true
        expect((await vaultManager.orders(vpeETH.target)).enabled).to.true
        expect((await vaultManager.orders(vpeETH.target)).beneficialAddress).to.equal(vault.target)
    })

    it("should user deposit successful", async function() {
        // mint 0.5 WETH as payment
        await mockWETH.mintTo(bob.address, toEther(0.5))
        await mockWETH.mintTo(charlie.address, toEther(0.5))

        // get proof of bob and charlie
        const proofBob = merkleTree.getProof([bob.address]);
        const proofCharlie = merkleTree.getProof([charlie.address]);

        //approve spender
        await mockWETH.connect(bob).approve(vault.target, ethers.MaxUint256);
        await mockWETH.connect(charlie).approve(vault.target, ethers.MaxUint256);

        // buy at 1:1 
        await vault.connect(bob).deposit(merkleTree.root, proofBob, vpeETH.target, toEther(0.5));
        await vault.connect(charlie).deposit(merkleTree.root, proofCharlie, vpeETH.target, toEther(0.5));

        //checking
        expect(await vpeETH.balanceOf(bob.address)).to.equal(toEther(0.5));
        expect(await vpeETH.balanceOf(charlie.address)).to.equal(toEther(0.5));
    })

    it("should operator rebase", async function() {
        // mint to operator 0.5 eth
        await mockWETH.mintTo(operator.address, toEther(0.5))
        await vault.connect(operator).rebase(vpeETH.target, toEther(0.2))
        await vault.connect(operator).rebase(vpeETH.target, toEther(0.3))

        const balanceBobAfterRebase = await vpeETH.balanceOf(bob.address);
        const balanceBobCharlieRebase = await vpeETH.balanceOf(charlie.address);

        //checking
        expect(balanceBobAfterRebase).to.equal(toEther(0.75));
        expect(balanceBobCharlieRebase).to.equal(toEther(0.75));

    })

    it("should request withdraw", async function() {
        // bob and charlie approve spender before request withdraw
        await vpeETH.connect(bob).approve(vault.target, ethers.MaxUint256)
        await vpeETH.connect(charlie).approve(vault.target, ethers.MaxUint256)



        // request withdrawal for both bob and charlie
        await vault.connect(bob).requestWithdraw(vpeETH.target, toEther(0.6))
        await vault.connect(charlie).requestWithdraw(vpeETH.target, toEther(0.6))

        // checking NFT metadata
        for (let id of Array.from([1, 2])) {
            const uri = await nft.tokenURI(id)
            expect(uri.includes(`VaporFund Withdraw NFT #${id}`)).to.true
        }
    })

    it("should operator swap total value out to total value in", async function() {
        // swap
        await mockWETH.mintTo(operator.address, toEther(0.3))
        await mockWETH.approve(vault.target, toEther(0.3))
        await vault.connect(operator).swapOutLpToInLp(vpeETH.target, toEther(0.3))
        const totalValueIn = await vault.totalValueInLp(vpeETH.target);
        expect(totalValueIn).to.equal(toEther(1.3));
    })

    it("should operator approve request", async function() {
        // approving
        await vault.connect(operator).approveRequestWithdraw([1, 2]);

    })
    it("should withdraw", async function() {
        // withdrawing
        await nft.connect(bob).approve(vault.target, 1);
        await nft.connect(charlie).approve(vault.target, 2);

        await vault.connect(bob).withdraw(1);
        await vault.connect(charlie).withdraw(2);

        // verifying
        expect(await mockWETH.balanceOf(bob.address)).to.equal(toEther(0.6))
        expect(await mockWETH.balanceOf(charlie.address)).to.equal(toEther(0.6))
        expect(await vault.getTotalPooledEther(vpeETH.target)).to.equal(toEther(0.3))

    })

    it("should swap total lp in to total lp out", async function() {
        // withdrawing
        const currentRequestId = await controller.getRequestCount();
        await vault.connect(operator).requestSwapInLpToOutLp(vpeETH.target, toEther(0.1), swap.address);

        await controller.connect(operator).confirmRequest(currentRequestId);
        await controller.connect(bob).confirmRequest(currentRequestId);
        await controller.connect(charlie).confirmRequest(currentRequestId);
        await controller.connect(charlie).executeRequest(currentRequestId);

        const balanceSwap = await mockWETH.balanceOf(swap.address);
        const totalValueIn = await vault.totalValueInLp(vpeETH.target);

        expect(balanceSwap).to.equal(toEther(0.1))
        expect(totalValueIn).to.equal(toEther(0))
    })
})