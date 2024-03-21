// Constants

#[inline(always)]
fn WORLD() -> starknet::ContractAddress {
    starknet::contract_address_const::<0x1>()
}

#[inline(always)]
fn ZERO() -> starknet::ContractAddress {
    starknet::contract_address_const::<0>()
}

#[inline(always)]
fn ERC20_ADDRESS() -> starknet::ContractAddress {
    starknet::contract_address_const::<0x3>()
}

#[inline(always)]
fn DEV_ADDRESS() -> starknet::ContractAddress {
    starknet::contract_address_const::<
        0x6162896d1d7ab204c7ccac6dd5f8e9e7c25ecd5ae4fcb4ad32e57786bb46e03
    >()
}

#[inline(always)]
fn DAO_ADDRESS() -> starknet::ContractAddress {
    starknet::contract_address_const::<
        0x6162896d1d7ab204c7ccac6dd5f8e9e7c25ecd5ae4fcb4ad32e57786bb46e03
    >()
}

// Powers

const TWO_POW_32: u128 = 4294967296;

// Dice constants

const DICE_FACES_NUMBER: u8 = 6;

// Hand constants

const HAND_MAX_SIZE: u8 = 5;
