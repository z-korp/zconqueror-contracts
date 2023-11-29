// Dojo imports

use dojo::world::IWorldDispatcher;

// System trait

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
        self: @TContractState,
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
        self: @TContractState, world: IWorldDispatcher, game_id: u32, tile_index: u8, supply: u32
    );
    fn transfer(
        self: @TContractState,
        world: IWorldDispatcher,
        game_id: u32,
        from_index: u8,
        to_index: u8,
        army: u32
    );
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

    // Models imports

    use zconqueror::models::game::{Game, GameTrait, Turn};
    use zconqueror::models::player::{Player, PlayerTrait};
    use zconqueror::models::tile::{Tile, TileTrait};
    use zconqueror::models::hand::HandTrait;
    use zconqueror::models::map::{Map, MapTrait};
    use zconqueror::models::set::SetTrait;

    // Internal imports

    use zconqueror::config::{TILE_NUMBER, ARMY_NUMBER};
    use zconqueror::store::{Store, StoreTrait};

    // Local imports

    use super::IPlay;

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

    #[external(v0)]
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
            assert(caller == player.address, errors::ATTACK_INVALID_PLAYER);

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
            self: @ContractState,
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
            assert(caller == player.address, errors::DEFEND_INVALID_PLAYER);

            // [Check] Tiles owner
            let mut attacker = store.tile(game, attacker_index);
            let mut defender = store.tile(game, defender_index);
            assert(attacker.owner == player.index.into(), errors::DEFEND_INVALID_OWNER);

            // [Compute] Defend
            let order = get_tx_info().unbox().transaction_hash;
            player.conqueror = defender.defend(ref attacker, game.seed, order);

            // [Effect] Update tiles
            store.set_tiles(array![attacker, defender].span());

            // [Effect] Update player
            store.set_player(player);
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
            assert(caller == player.address, errors::DISCARD_INVALID_PLAYER);

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
            assert(caller == player.address, errors::FINISH_INVALID_PLAYER);

            // [Check] Player supply is empty
            let mut player = store.current_player(game);
            assert(player.supply == 0, errors::FINISH_INVALID_SUPPLY);

            // [Command] Update next player supply if next turn is supply
            if game.next_turn() == Turn::Supply {
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
                let mut next_player = store.next_player(game);

                // [Compute] Supply, 0 if player is dead
                let score = map.score(next_player.index);
                next_player
                    .supply = if 0 == score.into() {
                        0
                    } else if score < 3 {
                        3
                    } else {
                        score
                    };
                store.set_player(next_player);
            }

            // [Effect] Update game
            game.increment();
            store.set_game(game);
        }

        fn supply(
            self: @ContractState, world: IWorldDispatcher, game_id: u32, tile_index: u8, supply: u32
        ) {
            // [Setup] Datastore
            let mut store: Store = StoreTrait::new(world);

            // [Check] Turn
            let mut game: Game = store.game(game_id);
            assert(game.turn() == Turn::Supply, errors::SUPPLY_INVALID_TURN);

            // [Check] Caller is player
            let caller = get_caller_address();
            let mut player = store.current_player(game);
            assert(caller == player.address, errors::SUPPLY_INVALID_PLAYER);

            // [Check] Tile owner
            let mut tile = store.tile(game, tile_index.into());
            assert(tile.owner == player.index.into(), errors::SUPPLY_INVALID_OWNER);

            // [Compute] Supply
            tile.supply(ref player, supply);

            // [Effect] Update tile
            store.set_tile(tile);

            // [Effect] Update player
            store.set_player(player);
        }

        fn transfer(
            self: @ContractState,
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
            assert(caller == player.address, errors::TRANSFER_INVALID_PLAYER);

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
