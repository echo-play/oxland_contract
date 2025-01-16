use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
use core::traits::Into;
use core::traits::{Drop};

#[derive(Drop, Serde, Copy, starknet::Store)]
struct Task {
    id: felt252,
    name: felt252,
    description: felt252,
    points_reward: u32,
    exp_reward: u32,
    daily: bool,
}

#[derive(Drop, Serde, Copy, starknet::Store)]
struct ShopItem {
    id: felt252,
    name: felt252,
    description: felt252,
    points_cost: u32,
    exp_requirement: u32,
    max_quantity: u32,
    cooldown: u64,
}

#[starknet::interface]
pub trait IOxland<TContractState> {
    fn get_points(self: @TContractState, address: ContractAddress) -> u32;
    fn get_experience(self: @TContractState, address: ContractAddress) -> u32;
    fn get_last_claim_timestamp(self: @TContractState, address: ContractAddress) -> u64;
    fn claim_daily_rewards(ref self: TContractState, address: ContractAddress);
    fn claim_points(ref self: TContractState, _points: u256);
    fn complete_task(ref self: TContractState, task_id: felt252);
    fn get_task_status(self: @TContractState, address: ContractAddress, task_id: felt252) -> bool;
    fn purchase_item(ref self: TContractState, item_id: felt252, quantity: u32);
    fn get_item_info(self: @TContractState, item_id: felt252) -> ShopItem;
    fn get_player_item_balance(self: @TContractState, address: ContractAddress, item_id: felt252) -> u32;
    fn get_level(self: @TContractState, address: ContractAddress) -> u32;
    fn get_level_exp_requirement(self: @TContractState, level: u32) -> u32;
    fn get_task_info(self: @TContractState, task_id: felt252) -> Task;
    fn get_item_effect(self: @TContractState, address: ContractAddress, item_id: felt252) -> (u64, u32);
    fn calculate_item_cost(self: @TContractState, item_id: felt252, quantity: u32) -> u32;
    fn get_item_effect_duration(self: @TContractState, item_id: felt252) -> u64;
    fn get_item_effect_bonus(self: @TContractState, item_id: felt252) -> u32;
}

#[starknet::contract]
pub mod Oxland {
    use super::*;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use super::super::erc20_interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    const ADMIN_ROLE: felt252 = 'ADMIN_ROLE';
    const OPERATOR_ROLE: felt252 = 'OPERATOR_ROLE';

    const POINTS_PER_DAY: u32 = 1_u32;
    const EXP_PER_DAY: u32 = 10_u32;
    const SECONDS_PER_DAY: u64 = 86400_u64;
    const MAX_CLAIM_POINTS: u256 = 1_u256;
    const POINTS_COST: u32 = 100_u32;
    const MIN_EXPERIENCE: u32 = 100_u32;
    const BASE_TASK_POINTS: u32 = 10_u32;
    const BASE_TASK_EXP: u32 = 5_u32;
    const BASE_ITEM_COOLDOWN: u64 = 86400_u64; // 24 hours
    const MAX_ITEM_QUANTITY: u32 = 99_u32;

    struct Item {
        id: felt252,
        points_cost: u32,
        exp_requirement: u32,
    }

    #[storage]
    struct Storage {
        token_address: Map::<(), ContractAddress>,
        points: Map::<ContractAddress, u32>,
        experience: Map::<ContractAddress, u32>,
        last_claim_timestamp: Map::<ContractAddress, u64>,
        last_claim_points_timestamp: Map::<ContractAddress, u64>,
        
        // Level system
        level: Map::<ContractAddress, u32>,
        level_thresholds: Map::<u32, u32>,
        
        // Quest system
        daily_tasks_completion: Map::<(ContractAddress, felt252, u64), bool>, // player, task_id, date
        achievement_completion: Map::<(ContractAddress, felt252), bool>, // player, achievement_id
        
        // Shop system
        item_purchases: Map::<(ContractAddress, felt252), u32>, // player, item_id -> quantity owned
        last_purchase_timestamp: Map::<(ContractAddress, felt252), u64>, // player, item_id -> last purchase time
        item_effects: Map::<(ContractAddress, felt252), (u64, u32)>, // player, effect_type -> (expiry_timestamp, bonus_percentage)
        
        // Task and item configuration storage
        tasks: Map::<felt252, Task>,
        shop_items: Map::<felt252, ShopItem>,

        // Access control
        admin: Map::<(), ContractAddress>,
        operators: Map::<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        RewardClaimed: RewardClaimed,
        LevelUp: LevelUp,
        TaskCompleted: TaskCompleted,
        ItemPurchased: ItemPurchased,
        OperatorAdded: OperatorAdded,
        OperatorRemoved: OperatorRemoved,
        GamePaused: GamePaused,
        GameUnpaused: GameUnpaused,
    }

    #[derive(Drop, starknet::Event)]
    struct RewardClaimed {
        player: ContractAddress,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct LevelUp {
        player: ContractAddress,
        new_level: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct TaskCompleted {
        player: ContractAddress,
        task_id: felt252,
        reward_points: u32,
        reward_exp: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct ItemPurchased {
        player: ContractAddress,
        item_id: felt252,
        quantity: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct OperatorAdded {
        operator: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct OperatorRemoved {
        operator: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct GamePaused {
        admin: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct GameUnpaused {
        admin: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, _token_addr: ContractAddress, _admin: ContractAddress) {
        self.token_address.write((), _token_addr);
        self.admin.write((), _admin);
        self.initialize_game_data();
    }

    #[generate_trait]
    impl AccessControlImpl of AccessControlTrait {
        fn only_admin(self: @ContractState) {
            let caller = get_caller_address();
            assert(caller == self.admin.read(()), 'Caller is not admin');
        }

        fn only_operator(self: @ContractState) {
            let caller = get_caller_address();
            assert(
                caller == self.admin.read(()) || self.operators.read(caller),
                'Caller is not operator'
            );
        }
    }

    #[generate_trait]
    impl AdminImpl of AdminTrait {
        fn add_operator(ref self: ContractState, operator: ContractAddress) {
            self.only_admin();
            self.operators.write(operator, true);
            self.emit(OperatorAdded { operator });
        }

        fn remove_operator(ref self: ContractState, operator: ContractAddress) {
            self.only_admin();
            self.operators.write(operator, false);
            self.emit(OperatorRemoved { operator });
        }

        fn initialize_game_data(ref self: ContractState) {
            self.only_admin();
            self.level_thresholds.write(1, 0);
            self.level_thresholds.write(2, 100);
            self.level_thresholds.write(3, 250);
            self.level_thresholds.write(4, 450);
            self.level_thresholds.write(5, 700);
            self.level_thresholds.write(6, 1000);
            self.level_thresholds.write(7, 1350);
            self.level_thresholds.write(8, 1750);
            self.level_thresholds.write(9, 2200);
            self.level_thresholds.write(10, 2700);

            self.add_task(
                1, 
                'Daily Check-in', 
                'Login for rewards',
                10, 
                5, 
                true
            );

            self.add_shop_item(
                1,
                'EXP Booster',
                '+50% EXP/24h',
                100,
                2,
                2,
                72 * 3600
            );
        }

        fn add_task(
            ref self: ContractState,
            id: felt252,
            name: felt252,
            description: felt252,
            points_reward: u32,
            exp_reward: u32,
            daily: bool,
        ) {
            self.only_operator();
            self.tasks.write(
                id,
                Task {
                    id,
                    name,
                    description,
                    points_reward,
                    exp_reward,
                    daily,
                }
            );
        }

        fn add_shop_item(
            ref self: ContractState,
            id: felt252,
            name: felt252,
            description: felt252,
            points_cost: u32,
            exp_requirement: u32,
            max_quantity: u32,
            cooldown: u64,
        ) {
            self.only_operator();
            self.shop_items.write(
                id,
                ShopItem {
                    id,
                    name,
                    description,
                    points_cost,
                    exp_requirement,
                    max_quantity,
                    cooldown,
                }
            );
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn calculate_task_rewards(self: @ContractState, task_id: felt252) -> (u32, u32) {
            let task = self.tasks.read(task_id);
            (task.points_reward, task.exp_reward)
        }

        fn validate_purchase(self: @ContractState, address: ContractAddress, item_id: felt252, quantity: u32) {
            let player_level = self.level.read(address);
            let required_level = self.get_item_level_requirement(item_id);
            assert(player_level >= required_level, 'Insufficient level');
            
            let last_purchase = self.last_purchase_timestamp.read((address, item_id));
            let cooldown = self.get_item_cooldown(item_id);
            let current_timestamp = get_block_timestamp();
            assert(current_timestamp >= last_purchase + cooldown, 'Purchase in cooldown');
        }

        fn apply_item_effects(ref self: ContractState, address: ContractAddress, item_id: felt252) {
            let current_timestamp = get_block_timestamp();
            let effect_duration = Self::get_item_effect_duration(@self, item_id);
            let effect_bonus = Self::get_item_effect_bonus(@self, item_id);
            
            if effect_duration > 0 {
                self.item_effects.write(
                    (address, item_id),
                    (current_timestamp + effect_duration, effect_bonus)
                );
            }
        }

        fn get_item_level_requirement(self: @ContractState, item_id: felt252) -> u32 {
            let item = self.shop_items.read(item_id);
            item.exp_requirement
        }

        fn get_item_cooldown(self: @ContractState, item_id: felt252) -> u64 {
            let item = self.shop_items.read(item_id);
            item.cooldown
        }

        fn get_item_effect_duration(self: @ContractState, item_id: felt252) -> u64 {
            BASE_ITEM_COOLDOWN
        }

        fn get_item_effect_bonus(self: @ContractState, item_id: felt252) -> u32 {
            let item = self.shop_items.read(item_id);
            match item.id {
                0 => 50,
                1 => 50,
                2 => 5,
                _ => 0,
            }
        }

        fn check_and_update_level(ref self: ContractState, address: ContractAddress) {
            let current_exp = self.experience.read(address);
            let current_level = self.level.read(address);
            let next_level_exp = self.level_thresholds.read(current_level + 1);
            
            if current_exp >= next_level_exp {
                let new_level = current_level + 1;
                self.level.write(address, new_level);
                self.emit(LevelUp { player: address, new_level });
            }
        }
    }

    #[abi(embed_v0)]
    impl OxlandImpl of IOxland<ContractState> {
        fn get_points(self: @ContractState, address: ContractAddress) -> u32 {
            self.points.read(address)
        }

        fn get_experience(self: @ContractState, address: ContractAddress) -> u32 {
            self.experience.read(address)
        }

        fn get_last_claim_timestamp(self: @ContractState, address: ContractAddress) -> u64 {
            self.last_claim_timestamp.read(address)
        }
        
        fn claim_daily_rewards(ref self: ContractState, address: ContractAddress) {
            let caller = get_caller_address();
            assert(caller == address, 'Only self can claim rewards');
            
            let current_timestamp = get_block_timestamp();
            let last_claim = self.last_claim_timestamp.read(address);
            
            assert(current_timestamp >= last_claim + SECONDS_PER_DAY, 'Must wait 24 hours');
            
            let current_points = self.points.read(address);
            let current_exp = self.experience.read(address);
            
            self.points.write(address, current_points + POINTS_PER_DAY);
            self.experience.write(address, current_exp + EXP_PER_DAY);
            
            self.last_claim_timestamp.write(address, current_timestamp);
        }

        fn claim_points(ref self: ContractState, _points: u256) {
            let caller = get_caller_address();
            let current_timestamp = get_block_timestamp();
            let last_claim = self.last_claim_points_timestamp.read(caller);
            
            assert(current_timestamp >= last_claim + SECONDS_PER_DAY, 'Must wait 24 hours');
            assert(_points <= MAX_CLAIM_POINTS, 'Exceeds max points');

            let current_exp = self.experience.read(caller);
            assert(current_exp >= MIN_EXPERIENCE, 'Insufficient experience');

            let current_points = self.points.read(caller);
            assert(current_points >= POINTS_COST, 'Insufficient points');
            self.points.write(caller, current_points - POINTS_COST);

            let strk_erc20_contract = IERC20Dispatcher {
                contract_address: self.token_address.read(())
            };

            strk_erc20_contract.transfer(caller, _points);
            
            self.last_claim_points_timestamp.write(caller, current_timestamp);

            self.emit(RewardClaimed { player: caller, amount: _points });
        }

        fn complete_task(ref self: ContractState, task_id: felt252) {
            let caller = get_caller_address();
            let current_timestamp = get_block_timestamp();
            let current_date = current_timestamp / SECONDS_PER_DAY;
            
            let task = self.tasks.read(task_id);
            assert(task.id == task_id, 'Task does not exist');
            
            assert(!self.daily_tasks_completion.read((caller, task_id, current_date)), 'Task already completed');
            
            self.daily_tasks_completion.write((caller, task_id, current_date), true);
            
            let (reward_points, reward_exp) = InternalFunctions::calculate_task_rewards(@self, task_id);
            
            let current_points = self.points.read(caller);
            let current_exp = self.experience.read(caller);
            
            self.points.write(caller, current_points + reward_points);
            self.experience.write(caller, current_exp + reward_exp);
            
            self.emit(TaskCompleted { 
                player: caller, 
                task_id,
                reward_points,
                reward_exp
            });
            
            InternalFunctions::check_and_update_level(ref self, caller);
        }

        fn purchase_item(ref self: ContractState, item_id: felt252, quantity: u32) {
            let caller = get_caller_address();
            let current_timestamp = get_block_timestamp();
            
            let item = self.shop_items.read(item_id);
            assert(item.id == item_id, 'Item does not exist');
            
            assert(quantity > 0 && quantity <= MAX_ITEM_QUANTITY, 'Invalid quantity');
            
            InternalFunctions::validate_purchase(@self, caller, item_id, quantity);
            
            let item_cost = item.points_cost * quantity;
            let current_points = self.points.read(caller);
            assert(current_points >= item_cost, 'Insufficient points');
            
            self.points.write(caller, current_points - item_cost);
            
            let current_quantity = self.item_purchases.read((caller, item_id));
            self.item_purchases.write((caller, item_id), current_quantity + quantity);
            
            self.last_purchase_timestamp.write((caller, item_id), current_timestamp);
            
            InternalFunctions::apply_item_effects(ref self, caller, item_id);
            
            self.emit(ItemPurchased { 
                player: caller, 
                item_id,
                quantity 
            });
        }

        // Level system
        fn get_level(self: @ContractState, address: ContractAddress) -> u32 {
            self.level.read(address)
        }

        fn get_level_exp_requirement(self: @ContractState, level: u32) -> u32 {
            self.level_thresholds.read(level)
        }

        fn get_task_info(self: @ContractState, task_id: felt252) -> Task {
            self.tasks.read(task_id)
        }

        fn get_task_status(self: @ContractState, address: ContractAddress, task_id: felt252) -> bool {
            let current_timestamp = get_block_timestamp();
            let current_date = current_timestamp / SECONDS_PER_DAY;
            self.daily_tasks_completion.read((address, task_id, current_date))
        }

        fn get_item_info(self: @ContractState, item_id: felt252) -> ShopItem {
            self.shop_items.read(item_id)
        }

        fn get_player_item_balance(self: @ContractState, address: ContractAddress, item_id: felt252) -> u32 {
            self.item_purchases.read((address, item_id))
        }

        fn get_item_effect(self: @ContractState, address: ContractAddress, item_id: felt252) -> (u64, u32) {
            self.item_effects.read((address, item_id))
        }

        fn calculate_item_cost(self: @ContractState, item_id: felt252, quantity: u32) -> u32 {
            let item = self.shop_items.read(item_id);
            item.points_cost * quantity
        }

        fn get_item_effect_duration(self: @ContractState, item_id: felt252) -> u64 {
            // Default effect duration: 24 hours
            BASE_ITEM_COOLDOWN
        }

        fn get_item_effect_bonus(self: @ContractState, item_id: felt252) -> u32 {
            let item = self.shop_items.read(item_id);
            // Example: Return different bonus effects based on item ID
            match item.id {
                0 => 50, // EXP Booster +50%
                1 => 50, // Points Booster +50%
                2 => 5,  // Rare Badge +5%
                _ => 0,
            }
        }
    }   
}
