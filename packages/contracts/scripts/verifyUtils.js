async function verifyContract(contract, args) {
    try {
        await hre.run("verify:verify", {
            address: contract.target,
            constructorArguments: args,
        });
        console.log(`Contract verified: ${contract.target}`);
    } catch (error) {
        console.error(`Error verifying contract ${contract.target}:`, error);
    }
}

async function verifyImplementContract(contract, args) {
    const vaultImplementAddress = await upgrades.erc1967.getImplementationAddress(contract.target);
    try {
        await hre.run("verify:verify", {
            address: vaultImplementAddress,
            constructorArguments: args,
        });
        console.log(`Vault implementation address verified: ${vaultImplementAddress}`);
    } catch (error) {
        console.error(`Error verifying vault implementation address ${vaultImplementAddress}:`, error);
    }
}

module.exports = {
    verifyContract,
    verifyImplementContract
};