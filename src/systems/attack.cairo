// Dojo imports

use dojo::world::IWorldDispatcher;

// System trait

#[starknet::interface]
trait IAttack<TContractState> {
    fn attack(
        self: @TContractState,
        world: IWorldDispatcher,
        account: felt252,
        attacker_index: u8,
        defender_index: u8,
        dispatched: u32
    );
}

// System implementation

#[starknet::contract]
mod attack {
    // Starknet imports

    use starknet::{get_tx_info, get_caller_address};

    // Dojo imports

    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // Components imports

    use zrisk::components::game::{Game, GameTrait, Turn};
    use zrisk::components::player::Player;
    use zrisk::components::tile::Tile;

    // Entities imports

    use zrisk::entities::land::LandTrait;

    // Internal imports

    use zrisk::datastore::{DataStore, DataStoreTrait};
    use zrisk::config::TILE_NUMBER;

    // Local imports

    use super::IAttack;

    // Errors

    mod errors {
        const INVALID_TURN: felt252 = 'Attack: invalid turn';
        const INVALID_PLAYER: felt252 = 'Attack: invalid player';
        const INVALID_OWNER: felt252 = 'Attack: invalid owner';
    }

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl AttackImpl of IAttack<ContractState> {
        fn attack(
            self: @ContractState,
            world: IWorldDispatcher,
            account: felt252,
            attacker_index: u8,
            defender_index: u8,
            dispatched: u32
        ) {
            // [Setup] Datastore
            let mut datastore: DataStore = DataStoreTrait::new(world);

            // [Check] Turn
            let mut game: Game = datastore.game(account);
            assert(game.turn() == Turn::Attack, errors::INVALID_TURN);

            // [Check] Caller is player
            let caller = get_caller_address();
            let mut player = datastore.current_player(game);
            assert(caller == player.address, errors::INVALID_PLAYER);

            // [Check] Tiles owner
            let attacker_tile = datastore.tile(game, attacker_index);
            let defender_tile = datastore.tile(game, defender_index);
            assert(attacker_tile.owner == player.index.into(), errors::INVALID_OWNER);

            // [Compute] Attack
            let tiles = _attack(@game, @attacker_tile, @defender_tile, dispatched);

            // [Effect] Update tiles
            datastore.set_tiles(tiles);
        }
    }

    fn _attack(game: @Game, attacker: @Tile, defender: @Tile, dispatched: u32) -> Span<Tile> {
        let mut attacker_land = LandTrait::load(attacker);
        let mut defender_land = LandTrait::load(defender);
        let order = get_tx_info().unbox().transaction_hash;
        attacker_land.attack(dispatched, ref defender_land, order);
        array![attacker_land.dump(*game.id), defender_land.dump(*game.id)].span()
    }
}
