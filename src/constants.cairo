// Constants

fn ZERO() -> starknet::ContractAddress {
    starknet::contract_address_const::<0>()
}

// Powers

const TWO_POW_32: u128 = 4294967296;

// Dice constants

const DICE_FACES_NUMBER: u8 = 6;

// Hand constants

const HAND_MAX_SIZE: u8 = 5;
