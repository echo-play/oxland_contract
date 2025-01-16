# Contract Upgrade Details (Version 1)

## New Features

### 1. Level System

- Added level progression from Level 1 to 10
- Experience requirements for each level
- Level-up rewards with points and experience bonuses
- Automatic level-up checks after completing tasks

### 2. Quest System

- Daily quests implementation
- Achievement system
- Task completion tracking
- Reward distribution system

### 3. Shop System

- Item purchasing system
- Different types of items (boosters, badges)
- Cooldown mechanics
- Purchase limits
- Effect duration tracking

### 4. Access Control

- Admin role implementation
- Operator role system
- Game data initialization
- Task and shop item management

## New Storage Structures

### Level System Storage

- `level`: Maps player address to current level
- `level_thresholds`: Maps level number to required experience

### Quest System Storage

- `daily_tasks_completion`: Tracks daily task completion
- `achievement_completion`: Tracks achievement progress
- `tasks`: Stores task configurations

### Shop System Storage

- `item_purchases`: Tracks player's purchased items
- `last_purchase_timestamp`: Tracks purchase cooldowns
- `item_effects`: Stores active item effects
- `shop_items`: Stores item configurations

### Access Control Storage

- `admin`: Stores admin address
- `operators`: Maps operator addresses to their status

## New Events

- `LevelUp`: Emitted when a player levels up
- `TaskCompleted`: Emitted when a task is completed
- `ItemPurchased`: Emitted when an item is bought
- `OperatorAdded`: Emitted when an operator is added
- `OperatorRemoved`: Emitted when an operator is removed
- `GamePaused`: Emitted when game is paused
- `GameUnpaused`: Emitted when game is unpaused
