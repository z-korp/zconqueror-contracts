// Starknet imports

use starknet::ContractAddress;

// Internal imports

use zconqueror::constants;
use zconqueror::store::Store;

mod errors {
    const PLAYER_INVALID_RANK: felt252 = 'Player: invalid rank';
}

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
    rank: u8,
}

#[generate_trait]
impl PlayerImpl of PlayerTrait {
    #[inline(always)]
    fn new(game_id: u32, index: u32, address: ContractAddress, name: felt252) -> Player {
        Player { game_id, index, address, name, supply: 0, cards: 0, conqueror: false, rank: 0 }
    }

    #[inline(always)]
    fn rank(ref self: Player, rank: u8) {
        assert(rank > 0, errors::PLAYER_INVALID_RANK);
        self.rank = rank;
    }
}

impl DefaultPlayer of Default<Player> {
    #[inline(always)]
    fn default() -> Player {
        Player {
            game_id: 0,
            index: 0,
            address: constants::ZERO(),
            name: 0,
            supply: 0,
            cards: 0,
            conqueror: false,
            rank: 0,
        }
    }
}
