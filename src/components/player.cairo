use starknet::ContractAddress;

#[derive(Component, Copy, Drop, Serde, SerdeLen)]
struct Player {
    #[key]
    game_id: u32,
    #[key]
    index: u32,
    address: ContractAddress,
    name: felt252,
    supply: u32,
}

trait PlayerTrait {
    fn new(game_id: u32, index: u32, address: ContractAddress, name: felt252) -> Player;
}

impl PlayerImpl of PlayerTrait {
    fn new(game_id: u32, index: u32, address: ContractAddress, name: felt252) -> Player {
        Player { game_id, index, address, name, supply: 0 }
    }
}
