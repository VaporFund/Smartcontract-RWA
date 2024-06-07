const { ethers, upgrades } = require("hardhat");
const { verifyContract, verifyImplementContract } = require("./verifyUtils");

const EETH_PROXY = "0x35fa164735182de50811e8e2e824cfb9b6118ac2"
const LIQUIDITY_POOL_PROXY = "0x308861a430be4cce5502d0a12724771fc6daf216"
const NFT_PROXY = "0x7d5706f6ef3F89B3951E23e557CDFBC3239D4E2c"

async function deployContracts() {
    // Fetch signers
    const [operator, bob, charlie, dave] = await ethers.getSigners();
    console.table({ operator, bob, charlie, dave });

    // Deploy system contracts
    const MultiSigController = await ethers.getContractFactory("MultiSigController");
    const Vault = await ethers.getContractFactory("VaultStakingETH");
    const Forwarder = await ethers.getContractFactory("Forwarder");

    const controller = await upgrades.deployProxy(MultiSigController, [
        [operator.address, bob.address, charlie.address, dave.address], 2
    ], );
    await controller.waitForDeployment();

    const vault = await upgrades.deployProxy(Vault, [1, controller.target]);
    await vault.waitForDeployment();

    // Register etherfi's contract address to forwarder
    const forwarder = await upgrades.deployProxy(Forwarder, [controller.target, vault.target], );
    await forwarder.waitForDeployment();

    await controller.addContract(forwarder.target);
    await forwarder.register(1, LIQUIDITY_POOL_PROXY, EETH_PROXY, NFT_PROXY)
    await vault.setForwarder(forwarder.target)

    console.table({
        controllerAddress: controller.target,
        vaultAddress: vault.target,
        forwarderAddress: forwarder.target
    });

    await verifyContract(controller, [
        [operator.address, bob.address, charlie.address, dave.address], 2
    ]);
    await verifyImplementContract(controller, []);

    await verifyContract(vault, [1, controller.target]);
    await verifyImplementContract(vault, []);

    await verifyContract(forwarder, [controller.target, vault.target]);
    await verifyImplementContract(forwarder, []);

}
deployContracts().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});