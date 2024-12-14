#[starknet::interface]
pub trait IOxland<TContractState> {
    fn get_points(self: @TContractState) -> u32;
    fn get_experience(self: @TContractState) -> u32;
    fn get_last_claim_timestamp(self: @TContractState) -> u64;
    fn claim_daily_rewards(ref self: TContractState);
    fn claimPoints(ref self: TContractState, _points: u256);
}

#[starknet::contract]
pub mod Oxland {
    use super::{IOxland};
    use starknet::{ContractAddress, get_caller_address};
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::super::erc20_interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    const POINTS_PER_DAY: u32 = 1_u32;
    const EXP_PER_DAY: u32 = 10_u32;
    const SECONDS_PER_DAY: u64 = 86400_u64;
    const MAX_CLAIM_POINTS: u256 = 1_u256;
    const POINTS_COST: u32 = 100_u32;
    const MIN_EXPERIENCE: u32 = 100_u32;

    #[storage]
    struct Storage {
        token_address: ContractAddress,
        points: u32,
        experience: u32,
        last_claim_timestamp: u64,
        last_claim_points_timestamp: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        RewardClaimed: RewardClaimed,
    }

    #[derive(Drop, starknet::Event)]
    struct RewardClaimed {
        player: ContractAddress,
        amount: u256
    }

    #[constructor]
    fn constructor(ref self: ContractState, _token_addr: ContractAddress) {
        self.token_address.write(_token_addr);
        self.points.write(0);
        self.experience.write(0);
        self.last_claim_timestamp.write(0);
        self.last_claim_points_timestamp.write(0);
    }

    #[abi(embed_v0)]
    impl OxlandImpl of IOxland<ContractState> {
        fn get_points(self: @ContractState) -> u32 {
            self.points.read()
        }

        fn get_experience(self: @ContractState) -> u32 {
            self.experience.read()
        }

        fn get_last_claim_timestamp(self: @ContractState) -> u64 {
            self.last_claim_timestamp.read()
        }
        
        fn claim_daily_rewards(ref self: ContractState) {
            let current_timestamp = starknet::get_block_timestamp();
            let last_claim = self.last_claim_timestamp.read();
            
            assert(current_timestamp >= last_claim + SECONDS_PER_DAY, 'Must wait 24 hours');
            
            self.points.write(self.points.read() + POINTS_PER_DAY);
            self.experience.write(self.experience.read() + EXP_PER_DAY);
            
            self.last_claim_timestamp.write(current_timestamp);
        }

        fn claimPoints(ref self: ContractState, _points: u256) {
            let caller = get_caller_address();
            let current_timestamp = starknet::get_block_timestamp();
            let last_claim = self.last_claim_points_timestamp.read();
            
            assert(current_timestamp >= last_claim + SECONDS_PER_DAY, 'Must wait 24 hours');
            
            assert(_points <= MAX_CLAIM_POINTS, 'Exceeds max points');

            let current_exp = self.experience.read();
            assert(current_exp >= MIN_EXPERIENCE, 'Insufficient experience');

            let current_points = self.points.read();
            assert(current_points >= POINTS_COST, 'Insufficient points');
            self.points.write(current_points - POINTS_COST);

            let strk_erc20_contract = IERC20Dispatcher {
                contract_address: self.token_address.read()
            };

            strk_erc20_contract.transfer(caller, _points);
            
            self.last_claim_points_timestamp.write(current_timestamp);

            self.emit(RewardClaimed { player: caller, amount: _points });
        }
    }   
}
