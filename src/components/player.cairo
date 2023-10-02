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

impl DefaultPlayer of Default<Player> {
    fn default() -> Player {
        let zero = starknet::contract_address_const::<0>();
        Player { game_id: 0, index: 0, address: zero, name: 0, supply: 0 }
    }
}
