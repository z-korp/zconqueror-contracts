// Dojo imports

use dojo::world::IWorldDispatcher;

// System trait

#[starknet::interface]
trait IHost<TContractState> {
    fn create(
        self: @TContractState, world: IWorldDispatcher, player_count: u8, player_name: felt252,
    );
    fn join(self: @TContractState, world: IWorldDispatcher, game_id: u32, player_name: felt252,);
    fn leave(self: @TContractState, world: IWorldDispatcher, game_id: u32,);
    fn start(self: @TContractState, world: IWorldDispatcher, game_id: u32,);
}

// System implementation

#[starknet::contract]
mod host {
    // Starknet imports

    use starknet::{get_tx_info, get_caller_address};

    // Dojo imports

    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // Models imports

    use zconqueror::models::game::{Game, GameTrait, Turn};
    use zconqueror::models::player::{Player, PlayerTrait};
    use zconqueror::models::tile::Tile;

    // Entities imports

    use zconqueror::entities::deck::DeckTrait;
    use zconqueror::entities::hand::HandTrait;
    use zconqueror::entities::land::{Land, LandTrait};
    use zconqueror::entities::map::{Map, MapTrait};
    use zconqueror::entities::set::SetTrait;

    // Internal imports

    use zconqueror::constants::ZERO;
    use zconqueror::config::{TILE_NUMBER, ARMY_NUMBER};
    use zconqueror::store::{Store, StoreTrait};
    use zconqueror::bot::simple::SimpleTrait;

    // Local imports

    use super::IHost;

    // Errors

    mod errors {
        const HOST_INVALID_PLAYER_COUNT: felt252 = 'Host: invalid player count';
        const HOST_PLAYER_ALREADY_IN_LOBBY: felt252 = 'Host: player already in lobby';
        const HOST_PLAYER_NOT_IN_LOBBY: felt252 = 'Host: player not in lobby';
    }

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl Host of IHost<ContractState> {
        fn create(
            self: @ContractState, world: IWorldDispatcher, player_count: u8, player_name: felt252,
        ) {
            // [Check] Player count
            // TODO: unlock more players
            assert(player_count == 1, errors::HOST_INVALID_PLAYER_COUNT);

            // [Setup] Datastore
            let mut store: Store = StoreTrait::new(world);

            // [Effect] Game
            let game_id = world.uuid();
            let player_address = get_caller_address();
            let mut game = GameTrait::new(
                id: game_id, host: player_address, player_count: player_count
            );
            let player_index: u32 = game.join(player_address).into();
            store.set_game(game);

            // [Effect] Player
            let player = PlayerTrait::new(
                game_id, index: player_index, address: player_address, name: player_name
            );
            store.set_player(player);
        }

        fn join(
            self: @ContractState, world: IWorldDispatcher, game_id: u32, player_name: felt252,
        ) {
            // [Setup] Datastore
            let mut store: Store = StoreTrait::new(world);

            // [Check] Player not in lobby
            let mut game = store.game(game_id);
            let player_address = get_caller_address();
            match store.find_player(game, player_address) {
                Option::Some(_) => panic(array![errors::HOST_PLAYER_ALREADY_IN_LOBBY]),
                Option::None => (),
            };

            // [Effect] Game
            let player_index: u32 = game.join(player_address).into();
            store.set_game(game);

            // [Effect] Player
            let player = PlayerTrait::new(
                game_id, index: player_index, address: player_address, name: player_name
            );
            store.set_player(player);
        }

        fn leave(self: @ContractState, world: IWorldDispatcher, game_id: u32,) {
            // [Setup] Datastore
            let mut store: Store = StoreTrait::new(world);

            // [Check] Player in lobby
            let mut game = store.game(game_id);
            let player_address = get_caller_address();
            let player = match store.find_player(game, player_address) {
                Option::Some(player) => player,
                Option::None => panic(array![errors::HOST_PLAYER_NOT_IN_LOBBY]),
            };

            // [Effect] Game
            let last_index = game.leave(player_address);
            store.set_game(game);

            // [Effect] Player
            let mut last_player = store.player(game, last_index);
            last_player.index = player.index;
            store.set_player(last_player);
        }

        fn start(self: @ContractState, world: IWorldDispatcher, game_id: u32,) {
            // [Setup] Datastore
            let mut store: Store = StoreTrait::new(world);

            // [Effect] Game
            let mut game = store.game(game_id);
            let mut players = store.players(game);
            // Complete missing players with bots
            let mut missings = game.player_count.into() - players.len();
            loop {
                if missings == 0 {
                    break;
                };
                let player_address = ZERO();
                let player_index = game.join(player_address);
                let bot = PlayerTrait::new(
                    game_id, player_index.into(), address: player_address, name: 0
                );
                players.append(bot);
                missings - 1;
            };
            game.start(players.span());
            store.set_game(game);

            // [Effect] Tiles
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
                            store.set_tile(tile);
                        },
                        Option::None => { break; },
                    };
                };
                player_index += 1;
            };

            // [Effect] Players
            // Use the deck mechanism to define the player order
            // First player got his supply set
            let mut deck = DeckTrait::new(game.seed, game.player_count.into(), game.nonce);
            let mut player_index = 0;
            let mut ordered_players: Array<Player> = array![];
            loop {
                if deck.remaining == 0 {
                    break;
                };
                let index = deck.draw() - 1;
                let mut player = store.player(game, index);
                player.index = player_index;
                ordered_players.append(player);
                if player_index == 0 {
                    let player_score = map.score(player_index.into());
                    player.supply = if player_score < 3 {
                        3
                    } else {
                        player_score
                    };
                };
                player_index += 1;
            };
            // Store ordered players
            loop {
                match ordered_players.pop_front() {
                    Option::Some(player) => { store.set_player(player); },
                    Option::None => { break; },
                };
            };
        }
    }
}
