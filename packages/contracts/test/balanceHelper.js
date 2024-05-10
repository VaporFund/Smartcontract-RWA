const { expect } = require("chai");

describe("#balance-helper", function() {
    let BalanceHelper;
    let balanceHelper;
    let Token;
    let token;

    beforeEach(async function() {
        Token = await ethers.getContractFactory("MockERC20");
        token = await Token.deploy("erc20", "erc20", "18");

        BalanceHelper = await ethers.getContractFactory("BalanceHelper");
        balanceHelper = await BalanceHelper.deploy(1000); // Set maxQuery to 10 for testing
    });

    it("Should return correct balances", async function() {
        const accounts = await ethers.getSigners();
        const addresses = accounts.map((account) => account.address);

        // Mint some tokens to the random accounts
        for (let i = 0; i < addresses.length; i++) {
            const amount = getRandomAmount();
            await token.mintTo(addresses[i], amount);
        }

        // Query balances using BalanceHelper contract
        const balances = await balanceHelper.queryBalances(token.target, addresses);

        // Check if the balances match
        for (let i = 0; i < addresses.length; i++) {
            const balance = await token.balanceOf(addresses[i]);
            expect(balances[i]).to.equal(balance);
        }
    });
});

// Function to generate random amount of tokens for testing
function getRandomAmount() {
    return Math.floor(Math.random() * 100); // Adjust the range as needed
}