# Audit Requirements

This document outlines the smart contracts that require an audit.

## Contracts to be Audited

### 1. MultiSigController.sol
- **Description**: Manages multi-signature operations for secure contract interactions. This contract ensures that multiple signatures are required to authorize certain operations, enhancing security.

### 2. TokenFactory.sol
- **Description**: Facilitates the creation of new ERC20 tokens. This factory contract allows for the deployment of new tokens with customizable parameters such as name, symbol, decimals, and initial supply. It also includes the functionality for creating bearing tokens and yield-bearing tokens.

### 3. WhitelistManager.sol
- **Description**: Manages the whitelisting of addresses for various operations. This contract is used to maintain a list of approved addresses that are allowed to perform specific actions within the system.

### 4. WithdrawRequestNFT.sol
- **Description**: Handles NFT-based withdrawal requests. This contract allows users to create and manage withdrawal requests that are represented as NFTs, providing a secure and trackable method for withdrawal operations.

### 5. Restakings/
#### 5.1 VaultStakingBSC.sol
- **Description**: Manages staking operations on the Binance Smart Chain. This contract allows users to stake their tokens on the BSC network and earn rewards.

#### 5.2 VaultManage.sol
- **Description**: General staking management contract. This contract provides functionality for creating tokens, creating token pairs for staking, and configuration.

### 6. RWAs/
#### 6.1 HashnoteHelper.sol
- **Description**: Provides helper functions for Real World Assets (RWAs). This contract includes various utility functions to support RWA operations, providing rate functions to interact with the Hashnote teller.

#### 6.2 RoleManage.sol
- **Description**: Manages roles for RWAs. This contract defines and manages different roles required for handling RWAs, ensuring that only authorized addresses can perform certain actions.

#### 6.3 Trigger.sol
- **Description**: Manages triggers for RWA-related events. This contract allows for automatic buying and selling by workers.

#### 6.4 VaultRwa.sol
- **Description**: Manages the RWA vault. This contract handles the storage and management of RWAs, ensuring their security and proper handling.

#### 6.5 VaultRwaManage.sol
- **Description**: Provides functionality similar to Restakings. This contract provides additional functionality for creating token pairs, configuring modes for deposits, and other management operations.

### 7. utility/
#### 7.1 ElasticToken.sol
- **Description**: Manages an elastic supply token. This contract defines a token whose supply can be adjusted based on certain conditions or requirements, providing flexibility in token management. The amount of tokens will increment over time.

#### 7.2 YieldBearingToken.sol
- **Description**: Manages a yield-bearing token. This contract defines a token that generates yield for its holders, allowing them to earn rewards based on their token holdings. The profit of the token will increment over time, but the amount does not change.

## Directory Audit Structure

The audit file requires structure is organized as follows:

```plaintext
contract/
├── MultiSigController.sol
├── TokenFactory.sol
├── WhitelistManager.sol
├── WithdrawRequestNFT.sol
├── Restakings/
│   ├── VaultStakingBSC.sol
│   └── VaultManage.sol
├── RWAs/
│   ├── HashnoteHelper.sol
│   ├── RoleManage.sol
│   ├── Trigger.sol
│   ├── VaultRwa.sol
│   └── VaultRwaManage.sol
└── utility/
    ├── ElasticToken.sol
    └── YieldBearingToken.sol
```