const { ethers, upgrades } = require("hardhat")
const { expect } = require("chai")
const { toEther, fromEther, toStable } = require("../helper")
const { StandardMerkleTree } = require("@openzeppelin/merkle-tree"); // Change import to require
const helpers = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { generateWhiteSignature } = require("../whitelistManager");

//change rpc to mainnet to test this
//mainnet
const USYC_PROXY = "0x136471a34f6ef19fE571EFFC1CA711fdb8E49f2b"
const PYUSD_PROXY = "0x6c3ea9036406852006290770BEdFcAbA0e23A0e8"
const ORACLE_PROXY = "0x4c48bcb2160F8e0aDbf9D4F3B034f1e36d1f8b3e"
const TELLER_PROXY = "0x0a5EA26fdD38CF2Acb06Dc64198374C337879DAb"
const HASHNOTE_WHITELIST_PROXY = "0xCEDAfE1EaA250DA15c434A54ece8BA1702876e3A"
const HASHNOTE_AUTHORITY_PROXY = "0x470f3b37B9B20E13b0A2a5965Df6bD3f9640DFB4"
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
const WETH9_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
const UNISWAP_ROUTER = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45"

//https://github.com/Uniswap/v3-periphery/blob/v1.0.0/testnet-deploys.md
// sophia
// const USYC_PROXY = "0x38D3A3f8717F4DB1CcB4Ad7D8C755919440848A3"
// const PYUSD_PROXY = "0x1c7d4b196cb0c7b01d743fbc6116a902379c7238"
// const ORACLE_PROXY = "0x35b96d80C72f873bACc44A1fACfb1f5fac064f1a"
// const TELLER_PROXY = "0xc7EAAA902FD0896d8807bFc6D8887ee27795bA3D"
describe("#vault-rwa", () => {
    let yieldTokenTeller
    let roleManage
    let vault
    let whitelistManager
    let vaultManager
    let vpUSYC
    let nft
    let stableToken
    let hashnoteHelper
    let hashnoteWhitelistManager
    let hashnoteAuthorityManager
    let trigger
    let depositToken

    let operator
    let bob
    let charlie
    let dave
    let pyUsdWallet
    let startWallet
    let worker

    let merkleTree

    before(async() => {

        [operator, bob, charlie, dave, worker, unwhitelist] = await ethers.getSigners()

        const ownerPyUsdWallet = "0xCFFAd3200574698b78f32232aa9D63eABD290703"; // Paxos: Treasury
        await helpers.impersonateAccount(ownerPyUsdWallet);
        pyUsdWallet = await ethers.getSigner(ownerPyUsdWallet);


        const ownerStartWallet = "0x89e51fA8CA5D66cd220bAed62ED01e8951aa7c40"; // Paxos: Treasury
        await helpers.impersonateAccount(ownerStartWallet);
        startWallet = await ethers.getSigner(ownerStartWallet);

        const RoleManage = await ethers.getContractFactory("RoleManage")
        const VaultStaking = await ethers.getContractFactory("VaultRwa")
        const VaultManager = await ethers.getContractFactory("VaultRwaManager")
        const WhitelistManager = await ethers.getContractFactory("WhitelistManager");
        const TokenFactory = await ethers.getContractFactory("TokenFactory");
        const Trigger = await ethers.getContractFactory("Trigger");
        const HashnoteHelperFactory = await ethers.getContractFactory("HashnoteHelper")

        //deploy hashnoteHelper
        hashnoteHelper = await HashnoteHelperFactory.deploy(USYC_PROXY, PYUSD_PROXY, ORACLE_PROXY, TELLER_PROXY);

        //deploy roleManage
        roleManage = await RoleManage.deploy(operator.address);

        //deploy whitelist
        whitelistManager = await WhitelistManager.deploy();

        //deploy vault manager
        vaultManager = await upgrades.deployProxy(VaultManager, [roleManage.target]);

        //deploy vault
        vault = await upgrades.deployProxy(VaultStaking, [1, roleManage.target, whitelistManager.target, vaultManager.target, UNISWAP_ROUTER]);

        // deploy trigger
        trigger = await Trigger.deploy(vaultManager.target, vault.target, roleManage.target);

        // set role operator for call vault
        const VAULT_RWA_OPERATOR_ROLE = vaultManager.VAULT_RWA_OPERATOR_ROLE()
        await roleManage.connect(operator).setRole(VAULT_RWA_OPERATOR_ROLE)
        await roleManage.connect(operator).setRoleAddress(VAULT_RWA_OPERATOR_ROLE, operator.address)

        // set role trigger contract for call vault
        const VAULT_RWA_CALLER_ROLE = vault.VAULT_RWA_CALLER_ROLE()
        await roleManage.connect(operator).setRole(VAULT_RWA_CALLER_ROLE)
        await roleManage.connect(operator).setRoleAddress(VAULT_RWA_CALLER_ROLE, trigger.target)

        // set role worker for call trigger contract
        const TRIGGER_CALLER_ROLE = trigger.TRIGGER_CALLER_ROLE()
        await roleManage.connect(operator).setRole(TRIGGER_CALLER_ROLE)
        await roleManage.connect(operator).setRoleAddress(TRIGGER_CALLER_ROLE, worker)

        // set role hashnote teller able use stable coin
        const VAULT_RWA_SPENDER_APPROVE_ROLE = vault.VAULT_RWA_SPENDER_APPROVE_ROLE()
        await roleManage.connect(operator).setRole(VAULT_RWA_SPENDER_APPROVE_ROLE)
        await roleManage.connect(operator).setRoleAddress(VAULT_RWA_SPENDER_APPROVE_ROLE, TELLER_PROXY)

        //set manager for vault
        await vaultManager.setVault(vault.target);

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
        await vaultManager.createToken("US Dollar Yield Token", "USYT", 6);
        vpUSYC = await ethers.getContractAt("IYieldToken", await vaultManager.bridgeTokens(0));

        // get nft contract
        const nftAddresss = await vault.withdrawNft()
        nft = await ethers.getContractAt("MockERC721", nftAddresss);

        // get hashnote teller contract
        yieldTokenTeller = await ethers.getContractAt("IYieldTokenTeller", TELLER_PROXY)

        // get usyc contract
        usycToken = await ethers.getContractAt("IYieldToken", USYC_PROXY)

        // get stable contract
        stableToken = await ethers.getContractAt("IPYUSDImplementation", PYUSD_PROXY)

        // get whitelist manage contract
        hashnoteWhitelistManager = await ethers.getContractAt("IHashnoteWhitelistManager", HASHNOTE_WHITELIST_PROXY)

        // get authority manage contract
        hashnoteAuthorityManager = await ethers.getContractAt("IHashnoteRolesAuthority", HASHNOTE_AUTHORITY_PROXY)

        // get contract for direct swap deposit
        depositToken = await ethers.getContractAt("IWETH9", USDC)

        await vault.connect(operator).approve(stableToken.target, TELLER_PROXY, ethers.MaxUint256)
    })



    it("should show error message hex ", async function() {
        // function show hex to debug
        const errorHex = []
        for (const errorMessage of[
                "AfterHours()",
                "BadAddress()",
                "BadAmount()",
                "ClosedForHoliday()",
                "ClosedForWeekend()",
                "InvalidTradingWindow()",
                "NoAccess()",
                "NotPermissioned()",
                "YearNotFound()",
            ]) {
            const hex = ethers.toUtf8Bytes(errorMessage);
            const hash = ethers.keccak256(hex);
            errorHex.push({
                errorMessage,
                hash
            })
        }
        console.table(errorHex)
    })

    it("should create new order success", async function() {
        // setup an order for eETH 
        await vaultManager.connect(operator).setupNewOrder(vpUSYC.target, stableToken.target, 0, hashnoteHelper.target)

        // checking
        expect((await vaultManager.orders(vpUSYC.target)).active).to.true
        expect((await vaultManager.orders(vpUSYC.target)).enabled).to.true
        expect((await vaultManager.orders(vpUSYC.target)).beneficialAddress).to.equal(vault.target)
    })

    it("should user deposit successful", async function() {
        // transfer 0.5 Stable token as payment
        await stableToken.connect(pyUsdWallet).transfer(bob.address, toStable(0.5));
        await stableToken.connect(pyUsdWallet).transfer(charlie.address, toStable(0.5));


        // get proof of bob and charlie
        const proofBob = merkleTree.getProof([bob.address]);
        const proofCharlie = merkleTree.getProof([charlie.address]);

        //approve spender
        await stableToken.connect(bob).approve(vault.target, ethers.MaxUint256);
        await stableToken.connect(charlie).approve(vault.target, ethers.MaxUint256);

        // buy at stable token
        await vault.connect(bob).deposit(merkleTree.root, proofBob, vpUSYC.target, [], toStable(0.5), 0, "0x", 0);
        await vault.connect(charlie).deposit(merkleTree.root, proofCharlie, vpUSYC.target, [], toStable(0.5), 0, "0x", 0);

        //checking
        expect(await vpUSYC.balanceOf(bob.address)).to.closeTo(toStable(0.5), toStable(0.51));
        expect(await vpUSYC.balanceOf(charlie.address)).to.closeTo(toStable(0.5), toStable(0.51));
    })


    it("should request withdraw", async function() {
        // bob and charlie approve spender before request withdraw
        await vpUSYC.connect(bob).approve(vault.target, ethers.MaxUint256)
        await vpUSYC.connect(charlie).approve(vault.target, ethers.MaxUint256)

        // request withdrawal for both bob and charlie
        await vault.connect(bob).requestWithdraw(vpUSYC.target, toStable(0.2))
        await vault.connect(charlie).requestWithdraw(vpUSYC.target, toStable(0.2))

        // checking NFT metadata
        for (let id of Array.from([1, 2])) {
            const uri = await nft.tokenURI(id)
            expect(uri.includes(`VaporFund Withdraw NFT #${id}`)).to.true
        }
    })

    it("should operator approve request", async function() {
        // approving
        await vault.connect(operator).approveRequestWithdraw([1, 2]);

    })

    it("should withdraw", async function() {
        // withdrawing
        await nft.connect(bob).approve(vault.target, 1);
        // await nft.connect(charlie).approve(vault.target, 2);

        await vault.connect(bob).withdraw(1, [], stableToken.target, 0);
        // await vault.connect(charlie).withdraw(2, [], stableToken.target, 0);

        // verifying
        expect(await stableToken.balanceOf(bob.address)).to.closeTo(toStable(0.2), toStable(0.21))
            // expect(await stableToken.balanceOf(charlie.address)).to.closeTo(toStable(0.2), toStable(0.21))
            // expect(await vault.getTotalPooledEther(vpUSYC.target)).to.equal(toEther(0.3))

    })

    it("should withdraw use swap", async function() {
        // withdrawing
        await nft.connect(charlie).approve(vault.target, 2);

        await vault.connect(charlie).withdraw(2, [{ tokenAddress: stableToken.target, poolFee: 3000 }], depositToken.target, 0);

        // verifying
        expect(await depositToken.balanceOf(charlie.address)).to.closeTo(toStable(0.2), toStable(0.21))
            // expect(await vault.getTotalPooledEther(vpUSYC.target)).to.equal(toEther(0.3))

    })

    it("mock permission for buyer", async function() {

        const addressOwnerWhitelist = "0xeE89a9eE62a5cC8a1FF4e9566ECe542856fE1C6D"; //mainnet owner whitelist address
        // const addressOwnerWhitelist = "0x8c1E7aB380bcBb4ed55A9402fb87F826C1ac5c82"; //sepolia owner whitelist address
        await helpers.impersonateAccount(addressOwnerWhitelist);
        const addressOwnerWhitelistSinger = await ethers.getSigner(addressOwnerWhitelist);
        await operator.sendTransaction({ to: addressOwnerWhitelist, value: toEther(1) }); // transfer gas fee for execute transaction


        // set role user domestic feeder
        const CLIENT_DOMESTIC_FEEDER = "0x81124843ba1ffbd10e87674b0d4ec85bac81e28b84f8d5b8030a3bd364dbbe73"
        await hashnoteWhitelistManager.connect(addressOwnerWhitelistSinger).grantRole(CLIENT_DOMESTIC_FEEDER, operator.address)
        await hashnoteWhitelistManager.connect(addressOwnerWhitelistSinger).grantRole(CLIENT_DOMESTIC_FEEDER, vault.target)

        // get status set role
        const roleWhitelistOperator = await hashnoteWhitelistManager.isClientDomesticFeeder(operator.address)
        const roleWhitelistVault = await hashnoteWhitelistManager.isClientDomesticFeeder(operator.address)
        expect(roleWhitelistOperator).is.true;
        expect(roleWhitelistVault).is.true;


        const addressOwnerAuthority = "0xeE89a9eE62a5cC8a1FF4e9566ECe542856fE1C6D"; //mainnet owner whitelist address
        // const addressOwnerAuthority = "0x8c1E7aB380bcBb4ed55A9402fb87F826C1ac5c82"; //sepolia owner whitelist address
        await operator.sendTransaction({ to: addressOwnerAuthority, value: toEther(1) });
        await helpers.impersonateAccount(addressOwnerAuthority);
        const addressOwnerAuthoritySinger = await ethers.getSigner(addressOwnerAuthority);

        // This is all role in authority
        // Investor_MFFeederDomestic,
        // Investor_MFFeederInternational,
        // Investor_SDYFDomestic,
        // Investor_SDYFInternational,
        // Investor_LOFDomestic,
        // Investor_LOFInternational,
        // Investor_Reserve1,
        // Investor_Reserve2,
        // Investor_Reserve3,
        // Investor_Reserve4,
        // Investor_Reserve5,
        // Custodian_Centralized,
        // Custodian_Decentralized,
        // System_FundAdmin,
        // System_Token,
        // System_Vault,
        // System_Auction,
        // System_Teller,
        // System_Oracle,
        // System_MarginEngine,
        // LiquidityProvider_Options,
        // LiquidityProvider_Spot

        // set role investor domestic feeder
        const role = 1;
        await hashnoteAuthorityManager.connect(addressOwnerAuthoritySinger).setUserRole(operator.address, role, true)
        await hashnoteAuthorityManager.connect(addressOwnerAuthoritySinger).setUserRole(vault.target, role, true)

        // get status set role
        const roleAuthorityOperator = await hashnoteAuthorityManager.doesUserHaveRole(operator.address, role)
        const roleAuthorityVault = await hashnoteAuthorityManager.doesUserHaveRole(vault.target, role)

        expect(roleAuthorityOperator).is.true;
        expect(roleAuthorityVault).is.true;

    })


    it("should real mainnet user able buy for", async function() {
        const buyer = "0xed96e247655361031aEE6514cD1b89C7141b59D5"; //mainnet owner whitelist address
        // const buyer = "0x8c1E7aB380bcBb4ed55A9402fb87F826C1ac5c82"; //sepolia owner whitelist address
        await operator.sendTransaction({ to: buyer, value: toEther(1) }); // transfer gas fee to execute transaction
        await helpers.impersonateAccount(buyer);
        const impersonatedSigner = await ethers.getSigner(buyer);


        await stableToken.connect(pyUsdWallet).transfer(impersonatedSigner.address, toStable(100)); // transfer stable token to user
        await stableToken.connect(impersonatedSigner).approve(TELLER_PROXY, toStable(100));
        await yieldTokenTeller.connect(impersonatedSigner).buy(1 * 10 ** 6);
    })

    it("should operator buy for", async function() {
        await stableToken.connect(pyUsdWallet).transfer(operator.address, toStable(100));
        await stableToken.connect(operator).approve(TELLER_PROXY, toStable(100));
        await yieldTokenTeller.connect(operator).buy(100 * 10 ** 6);


        const balanceOfOperatorUsyc = await usycToken.balanceOf(operator.address);
        expect(balanceOfOperatorUsyc).to.closeTo(toStable(100), toStable(10)) // yield bearing token value will less than by time

    })

    it("should trigger buy for", async function() {
        const balanceStableTokenBeforeBuy = await stableToken.balanceOf(vault.target);
        const balanceYieldTokenBeforeBuy = await usycToken.balanceOf(vault.target);
        expect(balanceStableTokenBeforeBuy).to.closeTo(toStable(0.6), toStable(0.1))
        expect(balanceYieldTokenBeforeBuy).to.closeTo(toStable(0), toStable(0))

        await trigger.connect(worker).buy(vpUSYC.target, toStable(0.2))

        const balanceStableTokenAfterBuy = await stableToken.balanceOf(vault.target);
        const balanceYieldTokenAfterBuy = await usycToken.balanceOf(vault.target);
        expect(balanceStableTokenAfterBuy).to.closeTo(toStable(0.4), toStable(0.1))
        expect(balanceYieldTokenAfterBuy).to.closeTo(toStable(0.2), toStable(0.02))
    })

    it("should trigger sell for", async function() {
        const balanceStableTokenBeforeBuy = await stableToken.balanceOf(vault.target);
        const balanceYieldTokenBeforeBuy = await usycToken.balanceOf(vault.target);

        expect(balanceStableTokenBeforeBuy).to.closeTo(toStable(0.4), toStable(0.1))
        expect(balanceYieldTokenBeforeBuy).to.closeTo(toStable(0.2), toStable(0.02))


        await trigger.connect(worker).sell(vpUSYC.target, toStable(0.1))

        const balanceStableTokenAfterBuy = await stableToken.balanceOf(vault.target);
        const balanceYieldTokenAfterBuy = await usycToken.balanceOf(vault.target);
        expect(balanceStableTokenAfterBuy).to.closeTo(toStable(0.5), toStable(0.1))
        expect(balanceYieldTokenAfterBuy).to.closeTo(toStable(0.1), toStable(0.01))
    })

    it("should user deposit after invert successful", async function() {
        // transfer 0.5 Stable token as payment
        await stableToken.connect(pyUsdWallet).transfer(bob.address, toStable(10));
        await stableToken.connect(pyUsdWallet).transfer(charlie.address, toStable(10));


        // get proof of bob and charlie
        const proofBob = merkleTree.getProof([bob.address]);
        const proofCharlie = merkleTree.getProof([charlie.address]);

        //approve spender
        await stableToken.connect(bob).approve(vault.target, ethers.MaxUint256);
        await stableToken.connect(charlie).approve(vault.target, ethers.MaxUint256);

        // buy at stable token
        await vault.connect(bob).deposit(merkleTree.root, proofBob, vpUSYC.target, [], toStable(10), 0, "0x", 0);
        await vault.connect(charlie).deposit(merkleTree.root, proofCharlie, vpUSYC.target, [], toStable(10), 0, "0x", 0);

        //checking
        expect(await vpUSYC.balanceOf(bob.address)).to.closeTo(toStable(10), toStable(1));
        expect(await vpUSYC.balanceOf(charlie.address)).to.closeTo(toStable(10), toStable(1));
    })

    it("should user deposit with uniswap successful", async function() {
        // transfer 10 Stable token as payment
        await operator.sendTransaction({ to: startWallet.address, value: toEther(1) }); // transfer gas fee to execute transaction

        await depositToken.connect(startWallet).transfer(bob.address, toStable(10));
        expect(await depositToken.balanceOf(bob.address)).to.equals(toStable(10));

        // get proof of bob and charlie
        const proofBob = merkleTree.getProof([bob.address]);

        //approve spender
        await stableToken.connect(bob).approve(vault.target, ethers.MaxUint256);
        await depositToken.connect(bob).approve(vault.target, ethers.MaxUint256);

        // buy at stable token
        await vault.connect(bob).deposit(merkleTree.root, proofBob, vpUSYC.target, [
            { tokenAddress: depositToken.target, poolFee: 3000 }
        ], toStable(10), 0, "0x", 0);

        //checking
        expect(await vpUSYC.balanceOf(bob.address)).to.closeTo(toStable(20), toStable(1));
    })

    it("should user deposit native with uniswap successful", async function() {
        // transfer 10 Stable token as payment
        await operator.sendTransaction({ to: startWallet.address, value: toEther(1) }); // transfer gas fee to execute transaction

        await depositToken.connect(startWallet).transfer(bob.address, toStable(10));
        expect(await depositToken.balanceOf(bob.address)).to.equals(toStable(10));

        // get proof of bob and charlie
        const proofBob = merkleTree.getProof([bob.address]);

        //approve spender
        await stableToken.connect(bob).approve(vault.target, ethers.MaxUint256);
        await depositToken.connect(bob).approve(vault.target, ethers.MaxUint256);

        // buy at path token
        await vault.connect(bob).deposit(merkleTree.root, proofBob, vpUSYC.target, [
            { tokenAddress: WETH9_ADDRESS, poolFee: 3000 },
            { tokenAddress: USDC, poolFee: 3000 }
        ], 0, 0, "0x", 0, { value: toEther(0.1) }); //~300usd

        //checking
        expect(await vpUSYC.balanceOf(bob.address)).to.closeTo(toStable(320), toStable(100));
        expect(await usycToken.balanceOf(vault.target)).to.closeTo(toStable(0.09), toStable(0.03));

    })

    it("should user deposit redirect with uniswap successful", async function() {
        await vaultManager.connect(operator).setRedirect(vpUSYC.target, true);

        await operator.sendTransaction({ to: startWallet.address, value: toEther(1) }); // transfer gas fee to execute transaction

        await depositToken.connect(startWallet).transfer(bob.address, toStable(10));

        // get proof of bob and charlie
        const proofBob = merkleTree.getProof([bob.address]);

        //approve spender
        await stableToken.connect(bob).approve(vault.target, ethers.MaxUint256);
        await depositToken.connect(bob).approve(vault.target, ethers.MaxUint256);

        // buy at stable token
        await vault.connect(bob).deposit(merkleTree.root, proofBob, vpUSYC.target, [
            { tokenAddress: depositToken.target, poolFee: 3000 }
        ], toStable(10), 0, "0x", 0);

        //checking
        expect(await usycToken.balanceOf(vault.target)).to.closeTo(toStable(10), toStable(10));
    })
    it("should user deposit with whitelist signature successful", async function() {
        await whitelistManager.setOracle(worker); // set oracle by whitelist for testing
        const leave = ethers.Wallet.createRandom();

        await operator.sendTransaction({ to: unwhitelist.address, value: toEther(1) }); // transfer gas fee to execute transaction
        // transfer 10 Stable token as payment
        await stableToken.connect(pyUsdWallet).transfer(unwhitelist.address, toStable(10));

        const merkleTree = StandardMerkleTree.of([
            [leave.address]
        ], ["address"]);
        const merkleRoot = merkleTree.root;

        // generate signature
        const signatureExpTime = 9999999999999;
        const signature = generateWhiteSignature(merkleRoot, signatureExpTime, worker)

        const proof = merkleTree.getProof([leave.address]);
        const isInWhitelistBefore = await whitelistManager.isInWhitelist(merkleRoot, leave, proof);
        expect(isInWhitelistBefore).to.be.false

        //approve spender
        await stableToken.connect(unwhitelist).approve(vault.target, ethers.MaxUint256);

        // buy at stable token
        await vault.connect(unwhitelist).deposit(merkleRoot, proof, vpUSYC.target, [], toStable(10), 0, signature, signatureExpTime);

        const isInWhitelistAfter = await whitelistManager.isInWhitelist(merkleRoot, leave, proof);
        expect(isInWhitelistAfter).to.be.true

        //checking
        expect(await vpUSYC.balanceOf(unwhitelist.address)).to.closeTo(toStable(10), toStable(1));
    })

    it("should withdraw redirect successful", async function() {
        // Get the initial balances of stable token and yield token
        const balanceStableBefore = await stableToken.balanceOf(bob.address);
        const balanceYieldBefore = await vpUSYC.balanceOf(bob.address);

        // Perform the withdrawal with redirect
        await vault.connect(bob).redirectWithdraw(vpUSYC.target, toStable(0.2), [], stableToken.target, 0);

        // Get the balances after the withdrawal
        const balanceStableAfter = await stableToken.balanceOf(bob.address);
        const balanceYieldAfter = await vpUSYC.balanceOf(bob.address);

        // Verifying the balances have changed as expected
        expect(balanceStableBefore < balanceStableAfter).to.be.true; // Expect balance of stable token to increase
        expect(balanceYieldBefore > balanceYieldAfter).to.be.true; // Expect balance of yield token to decrease
    });

    it("should withdraw redirect with uniswap successful", async function() {
        // Get the initial balances of stable token and yield token
        const balanceDepositTokenBefore = await depositToken.balanceOf(bob.address);
        const balanceYieldBefore = await vpUSYC.balanceOf(bob.address);

        // Perform the withdrawal with redirect
        await vault.connect(bob).redirectWithdraw(vpUSYC.target, toStable(0.2), [{ tokenAddress: stableToken.target, poolFee: 3000 }], depositToken.target, 0);

        // Get the balances after the withdrawal
        const balanceDepositTokenAfter = await depositToken.balanceOf(bob.address);
        const balanceYieldAfter = await vpUSYC.balanceOf(bob.address);

        // Verifying the balances have changed as expected
        expect(balanceDepositTokenBefore < balanceDepositTokenAfter).to.be.true; // Expect balance of stable token to increase
        expect(balanceYieldBefore > balanceYieldAfter).to.be.true; // Expect balance of yield token to decrease
    });


})