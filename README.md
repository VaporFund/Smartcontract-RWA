# vapor-core

VaporFund extends staking accessibility across chains by utilizing a specialized cross-chain bridge & DEX tailored for rebase tokens. Imagine getting eETH from [ether.fi](https://www.ether.fi/) and earning points from [EigenLayer](https://www.eigenlayer.xyz/) on the BNB chain with lower gas fees.

The project is inspired by the following works:
- ElasticBridge - https://github.com/nulltea/elastic-bridge/blob/main/ElasticBridgePaper.pdf
- ElasticSwap - https://github.com/ElasticSwap/elasticswap
- RealUSD - https://docs.tangible.store/real-usd/how-it-works/cross-chain-bridging

The system extends a common lock-and-mint concept for bridging assets across chains leveraging a reputable cross-chain messaging protocol in the industry to transmit arbitrary data. Whenever rebases occur on the parent chain, the elastic supply control module automatically adjusts the supply on the child chain. 

![vapor drawio (2) (1)](https://github.com/tamago-labs/vapor-core/assets/18402217/23b2f7c5-e488-4687-a47f-6f20e6777796)

Some rebase tokens mandate KYC verification. In such cases, a separate system manages the KYC process. After successful completion, the wallet address gets whitelisted, allowing it to acquire and transfer.

## Planned

- [v.1.0] Elastic cross-chain bridge allows for acquiring & withdrawing BNBeETH on BNB chain.
- [v.1.1] Rebase triggers reward distribution for BNBeETH holders.
- [v.1.2] Support BNBUSDY/OPUSDY that require KYC approval.
- [v.1.3] Using 3rd parties to automate cross-chain messaging and token transfers.

The multi-chain DEX specialized for rebase tokens aims to release sometime in 2024.




