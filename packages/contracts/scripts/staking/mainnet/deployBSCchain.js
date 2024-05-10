const { ethers, upgrades } = require("hardhat");
const { verifyImplementContract, verifyContract } = require("../verifyUtils");

async function deployContracts() {
    const [owner] = await ethers.getSigners()

    console.log({ ownerAddress: owner.address })

    const admin = "0x438427B04Ef898ff91aaE984068C06503B239853"
    const accountA = "0x016D294E93c1225216AC1025f24C9D055DAc1b61"
    const accountB = "0x00f53Dc247e786837C1e6BEAf276fc53fad80Bd8"
    const accountC = "0x60d2f7fCf78941d3991cb8c82069f974b77C736F"

    const MultiSigController = await ethers.getContractFactory("MultiSigController")
    const VaultStakingBSC = await ethers.getContractFactory("VaultStakingBSC")
    const VaultManager = await ethers.getContractFactory("VaultManager")
    const WhitelistManager = await ethers.getContractFactory("WhitelistManager");
    const TokenFactory = await ethers.getContractFactory("TokenFactory");

    //deploy controller
    const controller = await upgrades.deployProxy(MultiSigController, [
        owner.address, [owner.address, accountA, accountB, accountC], 2
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

    // get nft contract
    const nftAddresss = await vault.withdrawNft()
    nft = await ethers.getContractAt("WithdrawRequestNFT", nftAddresss);

    // create EETH token
    let tx1 = await vaultManager.createToken("Vapor Etherfi", "VPEETH", 18);
    await tx1.wait();
    vpeETH = await ethers.getContractAt("IElasticToken", await vaultManager.bridgeTokens(0));

    // add supported contract
    let tx2 = await controller.connect(owner).addContract(vaultManager.target)
    await tx2.wait()

    // add supported contract
    let tx3 = await controller.connect(owner).addContract(vault.target)
    await tx3.wait()

    let tx4 = await controller.connect(owner).transferAdmin(admin);
    await tx4.wait()


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
            owner.address, [owner.address, accountA, accountB, accountC], 2
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
        await verifyContract(vpeETH, ["Vapor Etherfi", "VPEETH", 18, vault.target]);

        await verifyContract(nft, [vault.target]);
    }

}
deployContracts().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});