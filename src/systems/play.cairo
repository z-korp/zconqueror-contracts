// Starknet imports

use starknet::ContractAddress;

// Dojo imports

use dojo::world::IWorldDispatcher;

// Interfaces

#[starknet::interface]
trait IPlay<TContractState> {
    fn attack(
        self: @TContractState,
        world: IWorldDispatcher,
        game_id: u32,
        attacker_index: u8,
        defender_index: u8,
        dispatched: u32
    );
    fn defend(
        ref self: TContractState,
        world: IWorldDispatcher,
        game_id: u32,
        attacker_index: u8,
        defender_index: u8
    );
    fn discard(
        self: @TContractState,
        world: IWorldDispatcher,
        game_id: u32,
        card_one: u8,
        card_two: u8,
        card_three: u8
    );
    fn finish(self: @TContractState, world: IWorldDispatcher, game_id: u32);
    fn supply(
        ref self: TContractState, world: IWorldDispatcher, game_id: u32, tile_index: u8, supply: u32
    );
    fn transfer(
        ref self: TContractState,
        world: IWorldDispatcher,
        game_id: u32,
        from_index: u8,
        to_index: u8,
        army: u32
    );
}

#[starknet::interface]
trait IERC20<TContractState> {
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
}

// System implementation

#[starknet::contract]
mod play {
    // Starknet imports

    use starknet::{get_tx_info, get_caller_address};

    // Dojo imports

    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // External imports

    use origami::random::deck::{Deck, DeckTrait};

    // Internal imports

    use zconqueror::models::game::{Game, GameTrait, Turn};
    use zconqueror::models::player::{Player, PlayerTrait};
    use zconqueror::models::tile::{Tile, TileTrait};
    use zconqueror::types::hand::HandTrait;
    use zconqueror::types::map::{Map, MapTrait};
    use zconqueror::types::set::SetTrait;
    use zconqueror::config::{TILE_NUMBER, ARMY_NUMBER};
    use zconqueror::store::{Store, StoreTrait};
    use zconqueror::constants;

    // Local imports

    use super::{IPlay, IERC20Dispatcher, IERC20DispatcherTrait};

    // Errors

    mod errors {
        const ATTACK_INVALID_TURN: felt252 = 'Attack: invalid turn';
        const ATTACK_INVALID_PLAYER: felt252 = 'Attack: invalid player';
        const ATTACK_INVALID_OWNER: felt252 = 'Attack: invalid owner';
        const DEFEND_INVALID_TURN: felt252 = 'Defend: invalid turn';
        const DEFEND_INVALID_PLAYER: felt252 = 'Defend: invalid player';
        const DEFEND_INVALID_OWNER: felt252 = 'Defend: invalid owner';
        const DISCARD_INVALID_TURN: felt252 = 'Discard: invalid turn';
        const DISCARD_INVALID_PLAYER: felt252 = 'Discard: invalid player';
        const FINISH_INVALID_PLAYER: felt252 = 'Finish: invalid player';
        const FINISH_INVALID_SUPPLY: felt252 = 'Finish: invalid supply';
        const SUPPLY_INVALID_TURN: felt252 = 'Supply: invalid turn';
        const SUPPLY_INVALID_PLAYER: felt252 = 'Supply: invalid player';
        const SUPPLY_INVALID_OWNER: felt252 = 'Supply: invalid owner';
        const TRANSFER_INVALID_TURN: felt252 = 'Transfer: invalid turn';
        const TRANSFER_INVALID_PLAYER: felt252 = 'Transfer: invalid player';
        const TRANSFER_INVALID_OWNER: felt252 = 'Transfer: invalid owner';
    }

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Supply: Supply,
        Defend: Defend,
        Fortify: Fortify,
    }

    #[derive(Drop, starknet::Event)]
    struct Supply {
        #[key]
        game_id: u32,
        #[key]
        player_name: felt252,
        troops: u32,
        region: u8,
    }

    #[derive(Drop, starknet::Event)]
    struct Defend {
        #[key]
        game_id: u32,
        #[key]
        attacker_name: felt252,
        #[key]
        defender_name: felt252,
        target_tile: u8,
        result: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct Fortify {
        #[key]
        game_id: u32,
        #[key]
        player_name: felt252,
        from_tile: u8,
        to_tile: u8,
        troops: u32,
    }

    #[abi(embed_v0)]
    impl Play of IPlay<ContractState> {
        fn attack(
            self: @ContractState,
            world: IWorldDispatcher,
            game_id: u32,
            attacker_index: u8,
            defender_index: u8,
            dispatched: u32
        ) {
            // [Setup] Datastore
            let mut store: Store = StoreTrait::new(world);

            // [Check] Turn
            let mut game: Game = store.game(game_id);
            assert(game.turn() == Turn::Attack, errors::ATTACK_INVALID_TURN);

            // [Check] Caller is player
            let caller = get_caller_address();
            let mut player = store.current_player(game);
            assert(player.address == caller.into(), errors::ATTACK_INVALID_PLAYER);

            // [Check] Tiles owner
            let mut attacker = store.tile(game, attacker_index);
            let mut defender = store.tile(game, defender_index);
            assert(attacker.owner == player.index.into(), errors::ATTACK_INVALID_OWNER);

            // [Compute] Attack
            let order = get_tx_info().unbox().transaction_hash;
            attacker.attack(dispatched, ref defender, order);

            // [Effect] Update tiles
            store.set_tiles(array![attacker, defender].span());
        }

        fn defend(
            ref self: ContractState,
            world: IWorldDispatcher,
            game_id: u32,
            attacker_index: u8,
            defender_index: u8
        ) {
            // [Setup] Datastore
            let mut store: Store = StoreTrait::new(world);

            // [Check] Turn
            let mut game: Game = store.game(game_id);
            assert(game.turn() == Turn::Attack, errors::DEFEND_INVALID_TURN);

            // [Check] Caller is player
            let caller = get_caller_address();
            let mut player = store.current_player(game);
            assert(player.address == caller.into(), errors::DEFEND_INVALID_PLAYER);

            // [Check] Tiles owner
            let mut attacker = store.tile(game, attacker_index);
            let mut defender = store.tile(game, defender_index);
            assert(attacker.owner == player.index.into(), errors::DEFEND_INVALID_OWNER);

            // [Compute] Defend
            let defender_player = store.player(game, defender.owner.try_into().unwrap());
            let order = get_tx_info().unbox().transaction_hash;
            player.conqueror = defender.defend(ref attacker, game.seed, order);

            // [Effect] Update tiles
            store.set_tiles(array![attacker, defender].span());

            // [Effect] Update player
            store.set_player(player);

            // [Event] Defend
            emit!(
                world,
                Defend {
                    game_id: game_id,
                    attacker_name: player.name,
                    defender_name: defender_player.name,
                    target_tile: defender_index,
                    result: player.conqueror,
                }
            );
        }

        fn discard(
            self: @ContractState,
            world: IWorldDispatcher,
            game_id: u32,
            card_one: u8,
            card_two: u8,
            card_three: u8
        ) {
            // [Setup] Datastore
            let mut store: Store = StoreTrait::new(world);

            // [Check] Turn
            let mut game: Game = store.game(game_id);
            assert(game.turn() == Turn::Supply, errors::DISCARD_INVALID_TURN);

            // [Check] Caller is player
            let caller = get_caller_address();
            let mut player = store.current_player(game);
            assert(player.address == caller.into(), errors::DISCARD_INVALID_PLAYER);

            // [Compute] Discard
            let tiles = store.tiles(game).span();
            let tiles = self._discard(@game, ref player, tiles, card_one, card_two, card_three);

            // [Effect] Update tiles
            store.set_tiles(tiles);

            // [Effect] Update player
            store.set_player(player);
        }

        fn finish(self: @ContractState, world: IWorldDispatcher, game_id: u32) {
            // [Setup] Datastore
            let mut store: Store = StoreTrait::new(world);

            // [Check] Caller is player
            let caller = get_caller_address();
            let mut game: Game = store.game(game_id);
            let mut player = store.current_player(game);
            assert(player.address == caller.into(), errors::FINISH_INVALID_PLAYER);

            // [Check] Player supply is empty
            let mut player = store.current_player(game);
            assert(player.supply == 0, errors::FINISH_INVALID_SUPPLY);

            // [Command] Update next player supply if next turn is supply
            game.increment();
            if game.turn() == Turn::Supply {
                // [Compute] Draw card if conqueror
                if player.conqueror {
                    let mut players = store.players(game).span();
                    self._draw(@game, ref player, ref players);
                    player.conqueror = false;
                    store.set_player(player);
                };

                // [Compute] Update player
                let tiles = store.tiles(game).span();
                let mut map = MapTrait::from_tiles(game.player_count.into(), tiles);

                // [Compute] Update next player to not dead player
                loop {
                    let mut next_player = store.current_player(game);
                    // [Check] Next player is the current player means game is over
                    if next_player.address == caller.into() {
                        // [Effect] Update player
                        next_player.rank(store.get_next_rank(game));
                        store.set_player(next_player);
                        // [Effect] Update game
                        game.over = true;
                        break;
                    };

                    // [Check] Player rank is not 0 means the player is dead, move to next player
                    if next_player.rank > 0 {
                        // [Effect] Move to next player
                        game.pass();
                        continue;
                    }

                    // [Check] Player score is 0 means the player is dead but not yet ranked, rank then move to next player
                    let score = map.score(next_player.index);
                    if 0 == score.into() {
                        // [Effect] Update player
                        next_player.rank(store.get_next_rank(game));
                        store.set_player(next_player);
                        // [Effect] Move to next player
                        game.pass();
                        continue;
                    } else {
                        // [Effect] Update next player supply and leave the loop
                        next_player.supply = if score < 3 {
                            3
                        } else {
                            score
                        };
                        store.set_player(next_player);
                        break;
                    };
                };
            };

            // [Effect] Update game
            store.set_game(game);
        }

        fn supply(
            ref self: ContractState,
            world: IWorldDispatcher,
            game_id: u32,
            tile_index: u8,
            supply: u32
        ) {
            // [Setup] Datastore
            let mut store: Store = StoreTrait::new(world);

            // [Check] Turn
            let mut game: Game = store.game(game_id);
            assert(game.turn() == Turn::Supply, errors::SUPPLY_INVALID_TURN);

            // [Check] Caller is player
            let caller = get_caller_address();
            let mut player = store.current_player(game);
            assert(player.address == caller.into(), errors::SUPPLY_INVALID_PLAYER);

            // [Check] Tile owner
            let mut tile = store.tile(game, tile_index.into());
            assert(tile.owner == player.index.into(), errors::SUPPLY_INVALID_OWNER);

            // [Compute] Supply
            tile.supply(ref player, supply);

            // [Effect] Update tile
            store.set_tile(tile);

            // [Effect] Update player
            store.set_player(player);

            // [Event] Supply
            emit!(
                world,
                Supply {
                    game_id: game_id, player_name: player.name, troops: supply, region: tile_index,
                }
            );
        }

        fn transfer(
            ref self: ContractState,
            world: IWorldDispatcher,
            game_id: u32,
            from_index: u8,
            to_index: u8,
            army: u32
        ) {
            // [Setup] Datastore
            let mut store: Store = StoreTrait::new(world);

            // [Check] Turn
            let mut game: Game = store.game(game_id);
            assert(game.turn() == Turn::Transfer, errors::TRANSFER_INVALID_TURN);

            // [Check] Caller is player
            let caller = get_caller_address();
            let mut player = store.current_player(game);
            assert(player.address == caller.into(), errors::TRANSFER_INVALID_PLAYER);

            // [Check] Tiles owner
            let mut from = store.tile(game, from_index);
            let mut to = store.tile(game, to_index);
            assert(from.owner == player.index.into(), errors::TRANSFER_INVALID_OWNER);

            // [Compute] Transfer
            let tiles = store.tiles(game).span();
            from.transfer(ref to, army, tiles);

            // [Effect] Update tiles
            store.set_tile(from);
            store.set_tile(to);

            // [Event] Fortify
            emit!(
                world,
                Fortify {
                    game_id: game_id,
                    player_name: player.name,
                    from_tile: from_index,
                    to_tile: to_index,
                    troops: army,
                }
            );
        }
    }

    #[generate_trait]
    impl Internal of InternalTrait {
        fn _draw(
            self: @ContractState, game: @Game, ref player: Player, ref players: Span<Player>,
        ) {
            // [Setup] Deck
            let mut deck = DeckTrait::new(*game.seed, TILE_NUMBER.into());
            deck.nonce = *game.nonce;
            loop {
                match players.pop_front() {
                    Option::Some(player) => {
                        let hand = HandTrait::load(player);
                        deck.remove(hand.cards.span());
                    },
                    Option::None => { break; },
                };
            };

            // [Compute] Set supply
            let mut hand = HandTrait::load(@player);
            hand.add(deck.draw());

            // [Effect] Player
            player.cards = hand.dump();
        }

        fn _discard(
            self: @ContractState,
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

            // [Effect] Update player cards and supply
            player.cards = hand.dump();
            player.supply += supply.into();

            // [Compute] Additional supplies for owned tiles
            let player_count = *game.player_count;
            let mut map = MapTrait::from_tiles(player_count.into(), tiles);
            let mut player_tiles = map.deploy(player.index, @set);

            // [Return] Player tiles
            let mut tiles: Array<Tile> = array![];
            loop {
                match player_tiles.pop_front() {
                    Option::Some(tile) => { tiles.append(*tile); },
                    Option::None => { break; },
                };
            };
            tiles.span()
        }
    }
}
