// Dojo imports

use dojo::world::IWorldDispatcher;

// System trait

#[starknet::interface]
trait ICreate<TContractState> {
    fn create(
        self: @TContractState,
        world: IWorldDispatcher,
        account: felt252,
        seed: felt252,
        name: felt252,
        player_count: u8
    );
}

// System implementation

#[starknet::contract]
mod create {
    // Starknet imports

    use starknet::get_caller_address;

    // Dojo imports

    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // Components imports

    use zrisk::components::game::{Game, GameTrait};
    use zrisk::components::player::{Player, PlayerTrait};
    use zrisk::components::tile::Tile;

    // Entities imports

    use zrisk::entities::map::MapTrait;
    use zrisk::entities::deck::DeckTrait;
    use zrisk::entities::land::{Land, LandTrait};

    // Internal imports

    use zrisk::datastore::{DataStore, DataStoreTrait};
    use zrisk::config::{TILE_NUMBER, ARMY_NUMBER};

    // Local imports

    use super::ICreate;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl CreateImpl of ICreate<ContractState> {
        fn create(
            self: @ContractState,
            world: IWorldDispatcher,
            account: felt252,
            seed: felt252,
            name: felt252,
            player_count: u8
        ) {
            // [Setup] Datastore
            let mut datastore: DataStore = DataStoreTrait::new(world);

            // [Effect] Game
            let game_id = world.uuid();
            let mut game = GameTrait::new(account, game_id, seed, player_count);
            datastore.set_game(game);

            // [Effect] Tile components
            let mut map = MapTrait::new(
                seed: game.seed,
                player_count: game.player_count.into(),
                land_count: TILE_NUMBER,
                army_count: ARMY_NUMBER
            );
            let mut player_index = 0;
            loop {
                if player_index == game.player_count {
                    break;
                }
                let mut player_lands = map.player_lands(player_index.into());
                loop {
                    match player_lands.pop_front() {
                        Option::Some(land) => {
                            let tile: Tile = land.dump(game.id);
                            datastore.set_tile(tile);
                        },
                        Option::None => {
                            break;
                        },
                    };
                };
                player_index += 1;
            };

            // [Effect] Player components
            // Use the deck mechanism to define the player order, human player is 1
            // First player got his supply set
            let caller = get_caller_address();
            let mut deck = DeckTrait::new(game.seed, game.player_count.into(), game.nonce);
            let mut player_index = 0;
            loop {
                if player_index == game.player_count {
                    break;
                };
                let card = deck.draw() - 1;
                let mut player = if card == 1 {
                    PlayerTrait::new(game_id, player_index.into(), address: caller, name: name)
                } else {
                    PlayerTrait::new(
                        game_id, player_index.into(), address: caller, name: card.into()
                    )
                };
                if player_index == 0 {
                    let player_score = map.score(player_index.into());
                    player.supply = if player_score < 3 {
                        3
                    } else {
                        player_score
                    };
                };
                datastore.set_player(player);
                player_index += 1;
            };
        }
    }
}
