// Dojo imports

use dojo::world::IWorldDispatcher;

// System trait

#[starknet::interface]
trait IFinish<TContractState> {
    fn finish(self: @TContractState, world: IWorldDispatcher, account: felt252);
}

// System implementation

#[starknet::contract]
mod finish {
    // Starknet imports

    use starknet::get_caller_address;

    // Dojo imports

    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // Components imports

    use zrisk::components::game::{Game, GameTrait, Turn};
    use zrisk::components::player::Player;
    use zrisk::components::tile::Tile;

    // Entities imports

    use zrisk::config;
    use zrisk::entities::deck::DeckTrait;
    use zrisk::entities::map::{Map, MapTrait};
    use zrisk::entities::land::{Land, LandTrait};
    use zrisk::entities::hand::{Hand, HandTrait};

    // Internal imports

    use zrisk::datastore::{DataStore, DataStoreTrait};
    use zrisk::config::TILE_NUMBER;

    // Local imports

    use super::IFinish;

    // Errors

    mod errors {
        const INVALID_PLAYER: felt252 = 'Finish: invalid player';
        const INVALID_SUPPLY: felt252 = 'Finish: invalid supply';
    }

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl FinishImpl of IFinish<ContractState> {
        fn finish(self: @ContractState, world: IWorldDispatcher, account: felt252) {
            // [Setup] Datastore
            let mut datastore: DataStore = DataStoreTrait::new(world);

            // [Check] Caller is player
            let caller = get_caller_address();
            let mut game: Game = datastore.game(account);
            let mut player = datastore.current_player(game);
            assert(caller == player.address, errors::INVALID_PLAYER);

            // [Compute] Finish
            let tiles = datastore.tiles(game);
            let mut next_player = datastore.next_player(game);
            _finish(ref game, ref player, ref next_player, tiles);

            // [Effect] Update players
            datastore.set_player(player);
            datastore.set_player(next_player);

            // [Effect] Update game
            datastore.set_game(game);
        }
    }

    fn _finish(ref game: Game, ref player: Player, ref next_player: Player, tiles: Span<Tile>) {
        // [Check] Player supply is empty
        assert(player.supply == 0, errors::INVALID_SUPPLY);

        // [Command] Update next player supply if next turn is supply
        if game.next_turn() == Turn::Supply {
            // [Compute] Draw card if conqueror
            // TODO

            // [Compute] Update player
            let player_count = game.player_count;
            let mut map = MapTrait::from_tiles(player_count.into(), tiles);
            next_player.conqueror = false;
            next_player.supply = map.score(next_player.index);
        }

        // [Compute] Update game
        game.increment();
    }
}
