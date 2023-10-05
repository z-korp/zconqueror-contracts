// Starknet imports

use starknet::ContractAddress;

// Internal imports

use zrisk::constants;

#[derive(Model, Copy, Drop, Serde)]
struct Player {
    #[key]
    game_id: u32,
    #[key]
    index: u32,
    address: ContractAddress,
    name: felt252,
    supply: u32,
    cards: u128,
    conqueror: bool,
}

trait PlayerTrait {
    fn new(game_id: u32, index: u32, address: ContractAddress, name: felt252) -> Player;
}

impl PlayerImpl of PlayerTrait {
    fn new(game_id: u32, index: u32, address: ContractAddress, name: felt252) -> Player {
        Player { game_id, index, address, name, supply: 0, cards: 0, conqueror: false }
    }
}

impl DefaultPlayer of Default<Player> {
    fn default() -> Player {
        Player {
            game_id: 0,
            index: 0,
            address: constants::ZERO(),
            name: 0,
            supply: 0,
            cards: 0,
            conqueror: false
        }
    }
}
