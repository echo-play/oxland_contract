# Oxland Smart Contract

Oxland is a gamified smart contract system built on StarkNet that allows users to earn points and experience through daily activities and redeem tokens as rewards.

## Deployment

The contract is currently deployed on StarkNet Sepolia testnet:

- Contract Address(Version 0): [0x5e4b06e146e53ebcc5681e3096312d911e213047af5a4fa82b0c516aeb55ee2](https://sepolia.starkscan.co/contract/0x5e4b06e146e53ebcc5681e3096312d911e213047af5a4fa82b0c516aeb55ee2)
- Upgrade Contract Address(Version 1): [0x500c401aa2403a36d40bca5e005be4ecf98a7842906cf6590b860082f265b95](https://sepolia.starkscan.co/contract/0x500c401aa2403a36d40bca5e005be4ecf98a7842906cf6590b860082f265b95)

## Features

### Core Features

- Daily reward system
- Experience accumulation
- Points system
- Token reward redemption

### New Features (Version 1)

- Level progression system
- Quest and achievement system
- Item shop with effects
- Access control system

## Contract Functions

### Core Functions

- `get_points`: Get player's points balance
- `get_experience`: Get player's experience
- `get_last_claim_timestamp`: Get last reward claim time
- `claim_daily_rewards`: Claim daily rewards
- `claim_points`: Redeem points for tokens

### Level System Functions

- `get_level`: Get player's current level
- `get_level_exp_requirement`: Get experience required for a level

### Quest System Functions

- `complete_task`: Complete a task
- `get_task_status`: Check task completion status
- `get_task_info`: Get task details

### Shop System Functions

- `purchase_item`: Purchase an item
- `get_item_info`: Get item details
- `get_player_item_balance`: Get player's item balance
- `get_item_effect`: Get active item effects
- `calculate_item_cost`: Calculate item purchase cost
- `get_item_effect_duration`: Get item effect duration
- `get_item_effect_bonus`: Get item effect bonus

## Technical Specifications

- Contract Language: Cairo 2.0
- Testing Framework: StarkNet Foundry
- Build Tool: Scarb

## Contract Structure

- `src/oxland.cairo`: Main contract implementation
- `src/erc20_interface.cairo`: ERC20 interface definition
- `tests/test_contract.cairo`: Test cases

## Key Constants

### Core Constants

- Daily Points Reward: 1 point
- Daily Experience Reward: 10 points
- Minimum Experience Required for Redemption: 100
- Points Cost for Redemption: 100
- Maximum Token Redemption Amount: 1

### New Constants (Version 1)

- Base Task Points: 10
- Base Task Experience: 5
- Base Item Cooldown: 24 hours
- Maximum Item Quantity: 99

## Installation and Testing

1. Install Dependencies
