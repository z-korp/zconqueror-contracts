// Starknet imports

use starknet::ContractAddress;

// Dojo imports

use dojo::world::IWorldDispatcher;

// Interfaces

#[starknet::interface]
trait IHost<TContractState> {
    fn create(
        self: @TContractState, world: IWorldDispatcher, player_name: felt252, price: u256
    ) -> u32;
    fn join(self: @TContractState, world: IWorldDispatcher, game_id: u32, player_name: felt252);
    fn leave(self: @TContractState, world: IWorldDispatcher, game_id: u32);
    fn start(self: @TContractState, world: IWorldDispatcher, game_id: u32);
    fn claim(self: @TContractState, world: IWorldDispatcher, game_id: u32);
}

#[starknet::interface]
trait IERC20<TContractState> {
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transferFrom(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
}

// System implementation

#[starknet::contract]
mod host {
    // Starknet imports

    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    // Dojo imports

    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // External imports

    use origami::random::deck::{Deck, DeckTrait};

    // Models imports

    use zconqueror::models::game::{Game, GameTrait};
    use zconqueror::models::player::{Player, PlayerTrait};
    use zconqueror::models::tile::{Tile, TileTrait};
    use zconqueror::types::map::{Map, MapTrait};
    use zconqueror::types::reward::{Reward, RewardTrait};
    use zconqueror::config::{TILE_NUMBER, ARMY_NUMBER};
    use zconqueror::store::{Store, StoreTrait};
    use zconqueror::constants;

    // Local imports

    use super::{IHost, IERC20Dispatcher, IERC20DispatcherTrait};

    // Errors

    mod errors {
        const ERC20_REWARD_FAILED: felt252 = 'ERC20: reward failed';
        const ERC20_PAY_FAILED: felt252 = 'ERC20: pay failed';
        const ERC20_REFUND_FAILED: felt252 = 'ERC20: refund failed';
        const HOST_PLAYER_ALREADY_IN_LOBBY: felt252 = 'Host: player already in lobby';
        const HOST_PLAYER_NOT_IN_LOBBY: felt252 = 'Host: player not in lobby';
        const HOST_CALLER_IS_NOT_THE_HOST: felt252 = 'Host: caller is not the host';
        const HOST_MAX_NB_PLAYERS_IS_TOO_LOW: felt252 = 'Host: max player numbers is < 2';
        const HOST_GAME_NOT_OVER: felt252 = 'Host: game not over';
    }

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl Host of IHost<ContractState> {
        fn create(
            self: @ContractState, world: IWorldDispatcher, player_name: felt252, price: u256
        ) -> u32 {
            // [Setup] Datastore
            let mut store: Store = StoreTrait::new(world);

            // [Interaction] Pay
            let player_address = get_caller_address();
            self._pay(world, player_address, price);

            // [Effect] Game
            let game_id = world.uuid();
            let mut game = GameTrait::new(id: game_id, host: player_address, price: price);
            let player_index: u32 = game.join().into();
            store.set_game(game);

            // [Effect] Player
            let player = PlayerTrait::new(
                game_id, index: player_index, address: player_address, name: player_name
            );
            store.set_player(player);

            // [Return] Game id
            game_id
        }

        fn join(self: @ContractState, world: IWorldDispatcher, game_id: u32, player_name: felt252) {
            // [Setup] Datastore
            let mut store: Store = StoreTrait::new(world);

            // [Check] Player not in lobby
            let mut game = store.game(game_id);
            let player_address = get_caller_address();
            match store.find_player(game, player_address) {
                Option::Some(_) => panic(array![errors::HOST_PLAYER_ALREADY_IN_LOBBY]),
                Option::None => (),
            };

            // [Interaction] Pay
            self._pay(world, player_address, game.price);

            // [Effect] Game
            let player_index: u32 = game.join().into();
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
            if last_player.index != player.index {
                last_player.index = player.index;
                store.set_player(last_player);
            }

            // [Interaction] Refund
            self._refund(world, player_address, game.price);
        }

        fn start(self: @ContractState, world: IWorldDispatcher, game_id: u32,) {
            // [Setup] Datastore
            let mut store: Store = StoreTrait::new(world);

            // [Check] Caller is the host
            let mut game = store.game(game_id);
            let caller = get_caller_address();
            assert(caller == game.host, errors::HOST_CALLER_IS_NOT_THE_HOST);

            // [Effect] Start game
            let mut addresses = array![];
            let mut players = store.players(game);
            loop {
                match players.pop_front() {
                    Option::Some(player) => { addresses.append(player.address); },
                    Option::None => { break; },
                };
            };
            game.start(addresses.span());
            store.set_game(game);

            // [Effect] Tiles
            let mut map = MapTrait::new(
                game_id: game.id,
                seed: game.seed,
                player_count: game.player_count.into(),
                tile_count: TILE_NUMBER,
                army_count: ARMY_NUMBER
            );
            let mut player_index = 0;
            loop {
                if player_index == game.player_count {
                    break;
                }
                let mut player_tiles = map.player_tiles(player_index.into());
                loop {
                    match player_tiles.pop_front() {
                        Option::Some(tile) => { store.set_tile(*tile); },
                        Option::None => { break; },
                    };
                };
                player_index += 1;
            };

            // [Effect] Players
            // Use the deck mechanism to define the player order
            // First player got his supply set
            let mut deck = DeckTrait::new(game.seed, game.player_count.into());
            let mut player_index = 0;
            let mut ordered_players: Array<Player> = array![];
            loop {
                if deck.remaining == 0 {
                    break;
                };
                let index = deck.draw() - 1;
                let mut player = store.player(game, index);
                player.index = player_index;
                if player_index == 0 {
                    let player_score = map.score(player_index.into());
                    player.supply = if player_score < 3 {
                        3
                    } else {
                        player_score
                    };
                };
                ordered_players.append(player);
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

        fn claim(self: @ContractState, world: IWorldDispatcher, game_id: u32,) {
            // [Setup] Datastore
            let mut store: Store = StoreTrait::new(world);

            // [Interaction] Distribute rewards
            let game = store.game(game_id);
            self._reward(game, game.reward(), ref store);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _pay(
            self: @ContractState, world: IWorldDispatcher, caller: ContractAddress, amount: u256
        ) {
            // [Check] Amount is not null, otherwise return
            if amount == 0 {
                return;
            }

            // [Interaction] Transfer
            let contract = get_contract_address();
            let erc20 = IERC20Dispatcher { contract_address: constants::ERC20_ADDRESS() };
            let status = erc20.transferFrom(caller, contract, amount);

            // [Check] Status
            assert(status, errors::ERC20_PAY_FAILED);
        }

        fn _refund(
            self: @ContractState, world: IWorldDispatcher, caller: ContractAddress, amount: u256
        ) {
            // [Check] Amount is not null, otherwise return
            if amount == 0 {
                return;
            }

            // [Interaction] Transfer
            let contract = get_contract_address();
            let erc20 = IERC20Dispatcher { contract_address: constants::ERC20_ADDRESS() };
            let status = erc20.transfer(caller, amount);

            // [Check] Status
            assert(status, errors::ERC20_REFUND_FAILED);
        }

        fn _reward(self: @ContractState, game: Game, amount: u256, ref store: Store,) {
            // [Check] Amount is not null, otherwise return
            if amount == 0 {
                return;
            }

            // [Setup] Top players
            let first = store.find_ranked_player(game, 1);
            let first_address = match first {
                Option::Some(player) => { player.address },
                Option::None => { constants::ZERO() },
            };

            let second = store.find_ranked_player(game, 2);
            let second_address = match second {
                Option::Some(player) => { player.address },
                Option::None => { constants::ZERO() },
            };

            let third = store.find_ranked_player(game, 3);
            let third_address = match third {
                Option::Some(player) => { player.address },
                Option::None => { constants::ZERO() },
            };

            // [Interaction] Transfers
            let erc20 = IERC20Dispatcher { contract_address: constants::ERC20_ADDRESS() };
            let mut rewards: Span<Reward> = RewardTrait::rewards(
                game.player_count, amount, first_address, second_address, third_address
            );
            loop {
                match rewards.pop_front() {
                    Option::Some(reward) => {
                        let status = erc20.transfer(*reward.recipient, *reward.amount);
                        assert(status, errors::ERC20_REWARD_FAILED);
                    },
                    Option::None => { break; },
                };
            }
        }
    }
}
