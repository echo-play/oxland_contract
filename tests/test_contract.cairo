use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank, start_warp, CheatTarget};
use starknet::{ContractAddress, contract_address_const};
use oxland_contract::oxland::{IOxlandDispatcher, IOxlandDispatcherTrait, Oxland};
use oxland_contract::erc20_interface::{IERC20Dispatcher, IERC20DispatcherTrait};

fn deploy_contract() -> ContractAddress {
    let contract = declare('Oxland');
    let token_address = contract_address_const::<0x1>();
    contract.deploy(@array![token_address.into()]).unwrap()
}

#[test]
fn test_initial_values() {
    let contract_address = deploy_contract();
    let dispatcher = IOxlandDispatcher { contract_address };

    assert_eq!(dispatcher.get_points(), 0, "Initial points should be 0");
    assert_eq!(dispatcher.get_experience(), 0, "Initial experience should be 0");
    assert_eq!(dispatcher.get_last_claim_timestamp(), 0, "Initial last claim timestamp should be 0");
}

#[test]
fn test_claim_daily_rewards() {
    let contract_address = deploy_contract();
    let dispatcher = IOxlandDispatcher { contract_address };
    
    // Warp to 24 hours later
    start_warp(CheatTarget::One(contract_address), 86400);
    
    dispatcher.claim_daily_rewards();
    
    assert_eq!(dispatcher.get_points(), 1, "Points should be 1 after claim");
    assert_eq!(dispatcher.get_experience(), 10, "Experience should be 10 after claim");
}

#[test]
#[should_panic(expected: ('Must wait 24 hours', ))]
fn test_claim_daily_rewards_too_early() {
    let contract_address = deploy_contract();
    let dispatcher = IOxlandDispatcher { contract_address };
    
    // Try to claim immediately
    dispatcher.claim_daily_rewards();
    // Try to claim again without waiting
    dispatcher.claim_daily_rewards();
}

#[test]
#[should_panic(expected: ('Insufficient experience', ))]
fn test_claim_points_insufficient_experience() {
    let contract_address = deploy_contract();
    let dispatcher = IOxlandDispatcher { contract_address };
    
    // Try to claim points without enough experience
    dispatcher.claimPoints(1);
}

#[test]
#[should_panic(expected: ('Insufficient points', ))]
fn test_claim_points_insufficient_points() {
    let contract_address = deploy_contract();
    let dispatcher = IOxlandDispatcher { contract_address };
    
    // First get enough experience
    start_warp(CheatTarget::One(contract_address), 86400 * 10);
    dispatcher.claim_daily_rewards();
    
    // Try to claim points without enough points
    dispatcher.claimPoints(1);
}
