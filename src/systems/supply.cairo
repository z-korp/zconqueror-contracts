// Dojo imports

use dojo::world::IWorldDispatcher;

// System trait

#[starknet::interface]
trait ISupply<TContractState> {
    fn supply(
        self: @TContractState,
        world: IWorldDispatcher,
        account: felt252,
        tile_index: u8,
        supply: u32
    );
}

// System implementation

#[starknet::contract]
mod supply {
    // Starknet imports

    use starknet::get_caller_address;

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

    use super::ISupply;

    // Errors

    mod errors {
        const INVALID_TURN: felt252 = 'Supply: invalid turn';
        const INVALID_PLAYER: felt252 = 'Supply: invalid player';
        const INVALID_OWNER: felt252 = 'Supply: invalid owner';
    }

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl SupplyImpl of ISupply<ContractState> {
        fn supply(
            self: @ContractState,
            world: IWorldDispatcher,
            account: felt252,
            tile_index: u8,
            supply: u32
        ) {
            // [Setup] Datastore
            let mut datastore: DataStore = DataStoreTrait::new(world);

            // [Check] Turn
            let mut game: Game = datastore.game(account);
            assert(game.turn() == Turn::Supply, errors::INVALID_TURN);

            // [Check] Caller is player
            let caller = get_caller_address();
            let mut player = datastore.current_player(game);
            assert(caller == player.address, errors::INVALID_PLAYER);

            // [Compute] Supply
            let tile = datastore.tile(game, tile_index.into());
            let tile = _supply(@game, ref player, @tile, supply);

            // [Effect] Update tile
            datastore.set_tile(tile);

            // [Effect] Update player
            datastore.set_player(player);
        }
    }

    fn _supply(game: @Game, ref player: Player, tile: @Tile, supply: u32) -> Tile {
        // [Check] Tile owner
        assert(tile.owner == @player.index.into(), errors::INVALID_OWNER);

        // [Compute] Supply
        let mut land = LandTrait::load(tile);
        land.supply(ref player, supply);

        // [Return] Update tile
        land.dump(*game.id)
    }
}
