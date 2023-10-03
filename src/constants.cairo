// Constants

fn ZERO() -> starknet::ContractAddress {
    starknet::contract_address_const::<0>()
}

// Dice constants

const DICE_FACES_NUMBER: u8 = 6;

// Hand constants

const HAND_MAX_SIZE: u8 = 5;
