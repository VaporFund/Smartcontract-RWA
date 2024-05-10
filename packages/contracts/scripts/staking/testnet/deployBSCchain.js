const { ethers, upgrades } = require("hardhat");
const { StandardMerkleTree } = require("@openzeppelin/merkle-tree"); // Change import to require
const { verifyImplementContract, verifyContract } = require("../verifyUtils");

async function deployContracts() {
    const [operator, bob, charlie, dave] = await ethers.getSigners()

    const MultiSigController = await ethers.getContractFactory("MultiSigController")
    const VaultStakingBSC = await ethers.getContractFactory("VaultStakingBSC")
    const VaultManager = await ethers.getContractFactory("VaultManager")
    const WhitelistManager = await ethers.getContractFactory("WhitelistManager");
    const TokenFactory = await ethers.getContractFactory("TokenFactory");

    //deploy controller
    const controller = await upgrades.deployProxy(MultiSigController, [
        operator.address, [operator.address, bob.address, charlie.address, dave.address], 2
    ]);
    await controller.waitForDeployment();

    //deploy whitelist
    const whitelistManager = await WhitelistManager.deploy();
    await whitelistManager.waitForDeployment();

    //deploy vault manager
    const vaultManager = await upgrades.deployProxy(VaultManager, [controller.target]);
    await vaultManager.waitForDeployment();

    //deploy vault
    const vault = await upgrades.deployProxy(VaultStakingBSC, [1, controller.target, whitelistManager.target, vaultManager.target]);
    await vault.waitForDeployment();

    //set manager for vault
    let tx = await vaultManager.setVault(vault.target);
    await tx.wait();

    //deploy factory
    const factory = await TokenFactory.deploy();
    await factory.waitForDeployment();

    //set factory to vault manage
    let tx1x = await vaultManager.setTokenFactory(factory.target);
    await tx1x.wait()

    // prefer user to whitelist
    const leaves = [operator, bob, charlie, dave].map(account => [account.address]);
    merkleTree = StandardMerkleTree.of(leaves, ["address"]);
    const merkleRoot = merkleTree.root;
    await whitelistManager.setRoot(merkleRoot, true);

    // create EETH token
    let tx1 = await vaultManager.createToken("Vapor Etherfi EETH", "VPEETH", 18);
    await tx1.wait();
    vpeETH = await ethers.getContractAt("IElasticToken", await vaultManager.bridgeTokens(0));

    // add supported contract
    let tx2 = await controller.connect(operator).addContract(vaultManager.target)
    await tx2.wait()

    // add supported contract
    let tx3 = await controller.connect(operator).addContract(vault.target)
    await tx3.wait()

    // get nft contract
    const nftAddresss = await vault.withdrawNft()
    nft = await ethers.getContractAt("WithdrawRequestNFT", nftAddresss);

    const addressB = {
        controllerBSCAddress: controller.target,
        vaultManagerAddress: vaultManager.target,
        whitelistManagerAddress: whitelistManager.target,
        vaultBSCAddress: vault.target,
        vaporEethAddress: vpeETH.target,
        ntfWithdrawAddress: nft.target,

    }
    console.table(addressB);

    for (let i = 0; i < 3; i++) {
        // verify for controller
        await verifyContract(controller, [
            operator.address, [operator.address, bob.address, charlie.address, dave.address], 2
        ]);
        await verifyImplementContract(controller, []);

        // verify for vault manage
        await verifyContract(vaultManager, [
            [controller.target], 2
        ]);
        await verifyImplementContract(vaultManager, []);

        //verify whitelist
        await verifyContract(whitelistManager, []);

        // verify for vault
        await verifyContract(vault, [1, controller.target, whitelistManager.target, vaultManager.target]);
        await verifyImplementContract(vault, []);

        //verify vapor eeth
        await verifyContract(vpeETH, ["Vapor Etherfi EETH", "VPEETH", 18, vault.target]);

        await verifyContract(nft, [vault.target]);
    }

}
deployContracts().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});