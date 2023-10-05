// Dojo imports

use dojo::world::IWorldDispatcher;

// System trait

#[starknet::interface]
trait IDiscard<TContractState> {
    fn discard(
        self: @TContractState,
        world: IWorldDispatcher,
        account: felt252,
        card_one: u8,
        card_two: u8,
        card_three: u8
    );
}

// System implementation

#[starknet::contract]
mod discard {
    // Starknet imports

    use starknet::get_caller_address;

    // Dojo imports

    use dojo::world::IWorldDispatcher;

    // Components imports

    use zrisk::components::game::{Game, GameTrait, Turn};
    use zrisk::components::player::Player;
    use zrisk::components::tile::Tile;

    // Entities imports

    use zrisk::entities::land::{Land, LandTrait};
    use zrisk::entities::hand::HandTrait;
    use zrisk::entities::set::SetTrait;
    use zrisk::entities::map::MapTrait;

    // Internal imports

    use zrisk::datastore::{DataStore, DataStoreTrait};
    use zrisk::config::TILE_NUMBER;

    // Local imports

    use super::IDiscard;

    // Errors

    mod errors {
        const INVALID_TURN: felt252 = 'Supply: invalid turn';
        const INVALID_PLAYER: felt252 = 'Supply: invalid player';
        const INVALID_OWNER: felt252 = 'Supply: invalid owner';
    }

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl DiscardImpl of IDiscard<ContractState> {
        fn discard(
            self: @ContractState,
            world: IWorldDispatcher,
            account: felt252,
            card_one: u8,
            card_two: u8,
            card_three: u8
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

            // [Compute] Discard
            let tiles = datastore.tiles(game);
            let tiles = _discard(@game, ref player, tiles, card_one, card_two, card_three);

            // [Effect] Update tiles
            datastore.set_tiles(tiles);

            // [Effect] Update player
            datastore.set_player(player);
        }
    }

    fn _discard(
        game: @Game,
        ref player: Player,
        mut tiles: Span<Tile>,
        card_one: u8,
        card_two: u8,
        card_three: u8
    ) -> Span<Tile> {
        // [Compute] Set supply
        let mut hand = HandTrait::load(@player);
        let set = SetTrait::new(card_one, card_two, card_three);
        let supply = hand.deploy(@set);
        player.supply += supply.into();

        // [Compute] Additional supplies for owned lands
        let player_count = *game.player_count;
        let mut map = MapTrait::from_tiles(player_count.into(), tiles);
        let mut player_lands = map.deploy(player.index, @set);

        // [Return] Player tiles
        let mut tiles: Array<Tile> = array![];
        loop {
            match player_lands.pop_front() {
                Option::Some(land) => {
                    let tile: Tile = land.dump(*game.id);
                    tiles.append(tile);
                },
                Option::None => {
                    break;
                },
            };
        };
        tiles.span()
    }
}
