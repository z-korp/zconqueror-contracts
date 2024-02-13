// Constants

#[inline(always)]
fn ZERO() -> starknet::ContractAddress {
    starknet::contract_address_const::<0>()
}

#[inline(always)]
fn ERC20_ADDRESS() -> starknet::ContractAddress {
    starknet::contract_address_const::<'TOKEN'>()
}

#[inline(always)]
fn DEV_ADDRESS() -> starknet::ContractAddress {
    starknet::contract_address_const::<'DEV'>()
}

#[inline(always)]
fn DAO_ADDRESS() -> starknet::ContractAddress {
    starknet::contract_address_const::<'DAO'>()
}

// Powers

const TWO_POW_32: u128 = 4294967296;

// Dice constants

const DICE_FACES_NUMBER: u8 = 6;

// Hand constants

const HAND_MAX_SIZE: u8 = 5;
