// Dojo imports

use dojo::world::IWorldDispatcher;

// System trait

#[starknet::interface]
trait ITransfer<TContractState> {
    fn transfer(
        self: @TContractState,
        world: IWorldDispatcher,
        account: felt252,
        source_index: u8,
        target_index: u8,
        army: u32
    );
}

// System implementation

#[starknet::contract]
mod transfer {
    // Starknet imports

    use starknet::get_caller_address;

    // Dojo imports

    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // Components imports

    use zrisk::components::game::{Game, GameTrait, Turn};
    use zrisk::components::player::Player;
    use zrisk::components::tile::Tile;

    // Entities imports

    use zrisk::entities::map::{Map, MapTrait};
    use zrisk::entities::land::{Land, LandTrait};

    // Internal imports

    use zrisk::datastore::{DataStore, DataStoreTrait};
    use zrisk::config::TILE_NUMBER;

    // Local imports

    use super::ITransfer;

    // Errors

    mod errors {
        const INVALID_TURN: felt252 = 'Transfer: invalid turn';
        const INVALID_PLAYER: felt252 = 'Transfer: invalid player';
        const INVALID_OWNER: felt252 = 'Transfer: invalid owner';
    }

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl TransferImpl of ITransfer<ContractState> {
        fn transfer(
            self: @ContractState,
            world: IWorldDispatcher,
            account: felt252,
            source_index: u8,
            target_index: u8,
            army: u32
        ) {
            // [Setup] Datastore
            let mut datastore: DataStore = DataStoreTrait::new(world);

            // [Check] Turn
            let mut game: Game = datastore.game(account);
            assert(game.turn() == Turn::Transfer, errors::INVALID_TURN);

            // [Check] Caller is player
            let caller = get_caller_address();
            let mut player = datastore.current_player(game);
            assert(caller == player.address, errors::INVALID_PLAYER);

            // [Check] Tiles owner
            let source = datastore.tile(game, source_index);
            let target = datastore.tile(game, target_index);
            assert(source.owner == player.index.into(), errors::INVALID_OWNER);

            // [Compute] Transfer
            let tiles = datastore.tiles(game);
            let (source, target) = _transfer(@game, @source, @target, tiles, army);

            // [Effect] Update tiles
            datastore.set_tile(source);
            datastore.set_tile(target);
        }
    }

    fn _transfer(
        game: @Game, source: @Tile, target: @Tile, mut tiles: Span<Tile>, army: u32
    ) -> (Tile, Tile) {
        // [Effect] Transfer
        let player_count = *game.player_count;
        let mut lands: Array<Land> = array![];
        loop {
            match tiles.pop_front() {
                Option::Some(tile) => {
                    let land = LandTrait::load(tile);
                    lands.append(land);
                },
                Option::None => {
                    break;
                },
            };
        };
        let mut from = LandTrait::load(source);
        let mut to = LandTrait::load(target);
        from.transfer(ref to, army, lands.span());
        (from.dump(*game.id), to.dump(*game.id))
    }
}
