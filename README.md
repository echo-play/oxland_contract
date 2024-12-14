# Oxland Smart Contract

Oxland is a gamified smart contract system built on StarkNet that allows users to earn points and experience through daily activities and redeem tokens as rewards.

## Deployment

The contract is currently deployed on StarkNet Sepolia testnet:

- Contract Address: [0x5e4b06e146e53ebcc5681e3096312d911e213047af5a4fa82b0c516aeb55ee2](https://sepolia.starkscan.co/contract/0x5e4b06e146e53ebcc5681e3096312d911e213047af5a4fa82b0c516aeb55ee2)

## Features

- Daily reward system
- Experience accumulation
- Points system
- Token reward redemption

## Technical Specifications

- Contract Language: Cairo 2.0
- Testing Framework: StarkNet Foundry
- Build Tool: Scarb

## Contract Structure

- `src/oxland.cairo`: Main contract implementation
- `src/erc20_interface.cairo`: ERC20 interface definition
- `tests/test_contract.cairo`: Test cases

## Key Constants

- Daily Points Reward: 1 point
- Daily Experience Reward: 10 points
- Minimum Experience Required for Redemption: 100
- Points Cost for Redemption: 100
- Maximum Token Redemption Amount: 1

## Installation and Testing

1. Install Dependencies
