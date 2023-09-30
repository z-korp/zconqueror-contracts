// Constants

fn ZERO() -> starknet::ContractAddress {
    starknet::contract_address_const::<0>()
}

// Deck constants

const DECK_CARDS_NUMBER: u32 = 42;

// Dice constants

const DICE_FACES_NUMBER: u8 = 6;
