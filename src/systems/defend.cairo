// Dojo imports

use dojo::world::IWorldDispatcher;

// System trait

#[starknet::interface]
trait IDefend<TContractState> {
    fn defend(
        self: @TContractState,
        world: IWorldDispatcher,
        account: felt252,
        attacker_index: u8,
        defender_index: u8
    );
}

// System implementation

#[starknet::contract]
mod defend {
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

    use super::IDefend;

    // Errors

    mod errors {
        const INVALID_TURN: felt252 = 'Defend: invalid turn';
        const INVALID_PLAYER: felt252 = 'Defend: invalid player';
        const INVALID_OWNER: felt252 = 'Defend: invalid owner';
    }

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl DefendImpl of IDefend<ContractState> {
        fn defend(
            self: @ContractState,
            world: IWorldDispatcher,
            account: felt252,
            attacker_index: u8,
            defender_index: u8
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

            // [Compute] Defend
            let tiles = _defend(@game, ref player, @attacker_tile, @defender_tile);

            // [Effect] Update tiles
            datastore.set_tiles(tiles);

            // [Effect] Update player
            datastore.set_player(player);
        }
    }

    fn _defend(game: @Game, ref player: Player, attacker: @Tile, defender: @Tile) -> Span<Tile> {
        let mut attacker_land = LandTrait::load(attacker);
        let mut defender_land = LandTrait::load(defender);
        let order = get_tx_info().unbox().transaction_hash;
        defender_land.defend(ref attacker_land, *game.seed, order);

        if defender_land.defeated && !player.conqueror {
            player.conqueror = true;
        };

        array![attacker_land.dump(*game.id), defender_land.dump(*game.id)].span()
    }
}
