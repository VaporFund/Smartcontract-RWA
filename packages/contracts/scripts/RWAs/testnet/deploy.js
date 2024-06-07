const { ethers, upgrades } = require("hardhat");
const { verifyImplementContract, verifyContract } = require("../../verifyUtils");
//uniswap : 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45

//sepolia 
const USYC_PROXY = "0x38D3A3f8717F4DB1CcB4Ad7D8C755919440848A3"
const STABLE_PROXY = "0xCaC524BcA292aaade2DF8A05cC58F0a65B1B3bB9"
const ORACLE_PROXY = "0x35b96d80C72f873bACc44A1fACfb1f5fac064f1a"
const TELLER_PROXY = "0x8C5d21F2DA253a117E8B89108be8FE781583C1dF"
const UNISWAP_ROUTER = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45" // router not support sophia

async function deployContracts() {
    const [operator, bob, charlie, dave, worker] = await ethers.getSigners()
    console.log({ operatorAddress: operator.address })
    console.table({ operator, bob, charlie, dave, worker })
    const RoleManage = await ethers.getContractFactory("RoleManage")
    const VaultStaking = await ethers.getContractFactory("VaultRwa")
    const VaultManager = await ethers.getContractFactory("VaultRwaManager")
    const WhitelistManager = await ethers.getContractFactory("WhitelistManager");
    const TokenFactory = await ethers.getContractFactory("TokenFactory");
    const Trigger = await ethers.getContractFactory("Trigger");
    const HashnoteHelperFactory = await ethers.getContractFactory("HashnoteHelper")

    // //for try deploy if ethereum slow
    // const hashnoteHelper = await ethers.getContractAt("HashnoteHelper", "0x97598fF18bA63344AdDdb3087f33F32Cbc3699C3");
    // const roleManage = await ethers.getContractAt("RoleManage", "0x4e48312148141fa4ABBEb2806490058c86AA8b95");
    // const whitelistManager = await ethers.getContractAt("WhitelistManager", "0xA729242abF17923463e0Bcdf7397cc29e543Bc13");
    // const vaultManager = await ethers.getContractAt("VaultRwaManager", "0x08f7492A005a772c09178Aec39171440277b6003");
    // const vault = await ethers.getContractAt("VaultRwa", "0x38efCc435b677d8c68bC48A4F2EDFDA1eD2917F3");
    // const trigger = await ethers.getContractAt("Trigger", "0x40bc45b56AeC07D580071F59B239D28374B67f3a");
    // const factory = await ethers.getContractAt("TokenFactory", "0xDaa37901f8293Df81b293C44dd2aB394510D13eF");

    //deploy hashnoteHelper
    const hashnoteHelper = await HashnoteHelperFactory.deploy(USYC_PROXY, STABLE_PROXY, ORACLE_PROXY, TELLER_PROXY);
    await hashnoteHelper.waitForDeployment()
    console.log({ hashnoteHelperAddress: hashnoteHelper.target })


    //deploy roleManage
    const roleManage = await RoleManage.deploy(operator.address);
    await roleManage.waitForDeployment()
    console.log({ roleManageAddress: roleManage.target })


    //deploy whitelist
    const whitelistManager = await WhitelistManager.deploy();
    await whitelistManager.waitForDeployment()
    console.log({ whitelistManagerAddress: whitelistManager.target })


    //deploy vault manager
    const vaultManager = await upgrades.deployProxy(VaultManager, [roleManage.target]);
    await vaultManager.waitForDeployment()
    console.log({ vaultManagerAddress: vaultManager.target })


    //deploy vault
    const vault = await upgrades.deployProxy(VaultStaking, [1, roleManage.target, whitelistManager.target, vaultManager.target, UNISWAP_ROUTER]);
    await vault.waitForDeployment()
    console.log({ vaultAddress: vault.target })

    // deploy trigger
    const trigger = await Trigger.deploy(vaultManager.target, vault.target, roleManage.target);
    await trigger.waitForDeployment()
    console.log({ triggerAddress: trigger.target })


    // set role operator for call vault
    const VAULT_RWA_OPERATOR_ROLE = vaultManager.VAULT_RWA_OPERATOR_ROLE()
    const tx1 = await roleManage.connect(operator).setRole(VAULT_RWA_OPERATOR_ROLE)
    await tx1.wait()

    const tx2 = await roleManage.connect(operator).setRoleAddress(VAULT_RWA_OPERATOR_ROLE, operator.address)
    await tx2.wait()

    const tx3 = await roleManage.connect(operator).setRoleAddress(VAULT_RWA_OPERATOR_ROLE, bob.address)
    await tx3.wait()

    const tx4 = await roleManage.connect(operator).setRoleAddress(VAULT_RWA_OPERATOR_ROLE, charlie.address)
    await tx4.wait()

    const tx5 = await roleManage.connect(operator).setRoleAddress(VAULT_RWA_OPERATOR_ROLE, dave.address)
    await tx5.wait()


    // set role trigger contract for call vault
    const VAULT_RWA_CALLER_ROLE = vault.VAULT_RWA_CALLER_ROLE()
    const tx6 = await roleManage.connect(operator).setRole(VAULT_RWA_CALLER_ROLE)
    await tx6.wait()

    const tx7 = await roleManage.connect(operator).setRoleAddress(VAULT_RWA_CALLER_ROLE, trigger.target)
    await tx7.wait()


    // set role worker for call trigger contract
    const TRIGGER_CALLER_ROLE = trigger.TRIGGER_CALLER_ROLE()

    const tx8 = await roleManage.connect(operator).setRole(TRIGGER_CALLER_ROLE)
    await tx8.wait()

    const tx9 = await roleManage.connect(operator).setRoleAddress(TRIGGER_CALLER_ROLE, worker.address)
    await tx9.wait()

    //set manager for vault
    const tx10 = await vaultManager.setVault(vault.target);
    await tx10.wait()


    //deploy factory
    const factory = await TokenFactory.deploy();
    await factory.waitForDeployment()
    console.log({ factoryAddress: factory.target })


    //set factory to vault manage
    const tx11 = await vaultManager.connect(operator).setTokenFactory(factory.target);
    await tx11.wait()


    // create EETH token
    const tx12 = await vaultManager.createToken("US Dollar Yield Token", "USYT", 6);
    await tx12.wait()
    const vpUSYC = await ethers.getContractAt("IYieldToken", await vaultManager.bridgeTokens(0));


    // get nft contract
    const nftAddresss = await vault.withdrawNft()
    const nft = await ethers.getContractAt("MockERC721", nftAddresss);


    // get stable contract
    const stableToken = await ethers.getContractAt("IPYUSDImplementation", STABLE_PROXY)


    // setup an order for eETH 
    const tx13 = await vaultManager.connect(operator).setupNewOrder(vpUSYC.target, stableToken.target, 0, hashnoteHelper.target)
    await tx13.wait()


    // set role hashnote teller able use stable coin
    const VAULT_RWA_SPENDER_APPROVE_ROLE = vault.VAULT_RWA_SPENDER_APPROVE_ROLE()
    const tx15 = await roleManage.connect(operator).setRole(VAULT_RWA_SPENDER_APPROVE_ROLE)
    await tx15.wait()
    const tx16 = await roleManage.connect(operator).setRoleAddress(VAULT_RWA_SPENDER_APPROVE_ROLE, TELLER_PROXY)
    await tx16.wait()

    // approve all for teller
    const tx14 = await vault.connect(operator).approve(STABLE_PROXY, TELLER_PROXY, ethers.MaxUint256)
    await tx14.wait()

    const addressB = {
        hashnoteHelperAddress: hashnoteHelper.target,
        roleManageAddress: roleManage.target,
        whitelistManagerAddress: whitelistManager.target,
        vaultManagerAddress: vaultManager.target,
        vaultAddress: vault.target,
        triggerAddress: trigger.target,
        vpUSYCAddress: vpUSYC.target,
        nftAddress: nft.target,
        stableTokenAddress: stableToken.target

    }
    console.table(addressB);

    for (let i = 0; i < 3; i++) {
        //verify hashnote helper
        await verifyContract(hashnoteHelper, [USYC_PROXY, STABLE_PROXY, ORACLE_PROXY, TELLER_PROXY]);

        //verify role manage
        await verifyContract(roleManage, [operator.address]);

        //verify whitelist manage
        await verifyContract(whitelistManager, []);

        //verify vault manage
        await verifyContract(vaultManager, [roleManage.target]);
        await verifyImplementContract(vaultManager, []);

        //verify nft trigger
        await verifyContract(vault, [1, roleManage.target, whitelistManager.target, vaultManager.target, UNISWAP_ROUTER]);
        await verifyImplementContract(vault, []);

        //verify trigger
        await verifyContract(trigger, [vaultManager.target, vault.target, roleManage.target]);

        //verify vapor usyc
        await verifyContract(vpUSYC, ["US Dollar Yield Token", "USYT", 6, vault.target]);

        //verify nft withdraw
        await verifyContract(nft, [vault.target]);

    }

}
deployContracts().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});