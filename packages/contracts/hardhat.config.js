require("@nomicfoundation/hardhat-chai-matchers");
require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("solidity-coverage");
require("hardhat-docgen");
require("hardhat-gas-reporter");
require("hardhat-contract-sizer");
require("hardhat-tracer");
require("hardhat-log-remover");
require('dotenv').config()

const RPC_HOST = process.env.RPC_HOST
const mnemonic = process.env.MNEMONIC

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    mocha: {
        timeout: 1200000,
    },
    solidity: {
        compilers: [{
            version: "0.8.20",
            settings: {
                optimizer: {
                    enabled: true,
                    runs: 200,
                    details: {
                        yul: true,
                    },
                },
                viaIR: true,
            }
        }]
    },
    gasReporter: {
        currency: 'USD',
        L1: "ethereum",
        coinmarketcap: process.env.COINMARKETCAP_API_KEY,
        enabled: true,
        gasPrice: "15"

    },
    networks: {
        hardhat: {
            chainId: 1,
            forking: {
                url: RPC_HOST
            },
            accounts: {
                mnemonic,
            },
        },
        vapor: {
            url: `https://dev-api-vaporfund.var-meta.com/rpc/eth-forked`,
            accounts: {
                mnemonic,
            },
        },
        mumbai: {
            url: `https://rpc.ankr.com/polygon_mumbai`,
            accounts: {
                mnemonic,
            },
        },
        bsctestnet: {
            url: `https://bsc-testnet.blockpi.network/v1/rpc/public`,
            accounts: {
                mnemonic,
            },
        },
        bscmainnet: {
            url: `https://bsc-dataseed1.binance.org/`,
            accounts: {
                mnemonic,
            },
        },
        ftmtestnet: {
            url: `https://rpc.testnet.fantom.network/`,
            accounts: {
                mnemonic,
            },
        },
        ethereum: {
            url: `https://eth-mainnet.nodereal.io/v1/2456fa948a554790b9b94187e55284c5`,
            accounts: {
                mnemonic,
            },
        },
        sepolia: {
            // url: `https://eth-sepolia.nodereal.io/v1/74f3cd44cce843debff83d0c1168315b`,
            url: `https://go.getblock.io/e505a902a6e840b6880cd5adb6b82344`,

            accounts: {
                mnemonic,
            },
        },
    },
    etherscan: {
        apiKey: {
            goerli: `${process.env.ETHERSCAN_KEY}`,
            sepolia: `${process.env.ETHERSCAN_KEY}`,
            polygonMumbai: `${process.env.POLYGONSCAN_KEY}`,
            mainnet: `${process.env.ETHERSCAN_KEY}`,
            bscTestnet: `${process.env.BSCSCAN_KEY}`,
            bsc: `${process.env.BSCSCAN_KEY}`,
            polygonMainnet: `${process.env.POLYGONSCAN_KEY}`,
            ftmTestnet: `${process.env.FANTOM_KEY}`,
        },
    },
    docgen: {
        path: "./docs",
        clear: true,
        runOnCompile: false,
    },
    contractSizer: {
        alphaSort: true,
        runOnCompile: true,
        disambiguatePaths: false,
    },
    typechain: {
        outDir: "typechain-types",
        target: "ethers-v6",
    },

};