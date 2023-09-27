use starknet::ContractAddress;

#[derive(Component, Copy, Drop, Serde, SerdeLen)]
struct Player {
    #[key]
    game_id: u32,
    #[key]
    order: u8,
    name: felt252,
}

trait PlayerTrait {
    fn new(game_id: u32, order: u8, name: felt252) -> Player;
}

impl PlayerImpl of PlayerTrait {
    fn new(game_id: u32, order: u8, name: felt252) -> Player {
        Player { game_id, order, name }
    }
}
