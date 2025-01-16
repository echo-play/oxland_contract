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
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use super::super::erc20_interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    const POINTS_PER_DAY: u32 = 1_u32;
    const EXP_PER_DAY: u32 = 10_u32;
    const SECONDS_PER_DAY: u64 = 86400_u64;
    const MAX_CLAIM_POINTS: u256 = 1_u256;
    const POINTS_COST: u32 = 100_u32;
    const MIN_EXPERIENCE: u32 = 100_u32;

    #[storage]
    struct Storage {
        token_address: Map::<(), ContractAddress>,
        points: Map::<ContractAddress, u32>,
        experience: Map::<ContractAddress, u32>,
        last_claim_timestamp: Map::<ContractAddress, u64>,
        last_claim_points_timestamp: Map::<ContractAddress, u64>,
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
        self.token_address.write((), _token_addr);
    }

    #[abi(embed_v0)]
    impl OxlandImpl of IOxland<ContractState> {
        fn get_points(self: @ContractState) -> u32 {
            let caller = get_caller_address();
            self.points.read(caller)
        }

        fn get_experience(self: @ContractState) -> u32 {
            let caller = get_caller_address();
            self.experience.read(caller)
        }

        fn get_last_claim_timestamp(self: @ContractState) -> u64 {
            let caller = get_caller_address();
            self.last_claim_timestamp.read(caller)
        }
        
        fn claim_daily_rewards(ref self: ContractState) {
            let caller = get_caller_address();
            let current_timestamp = starknet::get_block_timestamp();
            let last_claim = self.last_claim_timestamp.read(caller);
            
            assert(current_timestamp >= last_claim + SECONDS_PER_DAY, 'Must wait 24 hours');
            
            let current_points = self.points.read(caller);
            let current_exp = self.experience.read(caller);
            
            self.points.write(caller, current_points + POINTS_PER_DAY);
            self.experience.write(caller, current_exp + EXP_PER_DAY);
            
            self.last_claim_timestamp.write(caller, current_timestamp);
        }

        fn claimPoints(ref self: ContractState, _points: u256) {
            let caller = get_caller_address();
            let current_timestamp = starknet::get_block_timestamp();
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
    }   
}
