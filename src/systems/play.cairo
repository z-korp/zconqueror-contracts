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
        source_index: u8,
        target_index: u8,
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
    use zconqueror::models::tile::Tile;

    // Entities imports

    use zconqueror::entities::hand::HandTrait;
    use zconqueror::entities::land::{Land, LandTrait};
    use zconqueror::entities::map::{Map, MapTrait};
    use zconqueror::entities::set::SetTrait;

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
            let attacker_tile = store.tile(game, attacker_index);
            let defender_tile = store.tile(game, defender_index);
            assert(attacker_tile.owner == player.index.into(), errors::ATTACK_INVALID_OWNER);

            // [Compute] Attack
            let tiles = self._attack(@game, @attacker_tile, @defender_tile, dispatched);

            // [Effect] Update tiles
            store.set_tiles(tiles);
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
            let attacker_tile = store.tile(game, attacker_index);
            let defender_tile = store.tile(game, defender_index);
            assert(attacker_tile.owner == player.index.into(), errors::DEFEND_INVALID_OWNER);

            // [Compute] Defend
            let tiles = self._defend(@game, ref player, @attacker_tile, @defender_tile);

            // [Effect] Update tiles
            store.set_tiles(tiles);

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
            let player = store.current_player(game);
            assert(player.supply == 0, errors::FINISH_INVALID_SUPPLY);

            // [Command] Update next player supply if next turn is supply
            if game.next_turn() == Turn::Supply {
                // [Compute] Draw card if conqueror
                // TODO

                // [Compute] Update player
                let tiles = store.tiles(game).span();
                let mut map = MapTrait::from_tiles(game.player_count.into(), tiles);
                let mut next_player = store.next_player(game);
                next_player.conqueror = false;

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

            // [Compute] Supply
            let tile = store.tile(game, tile_index.into());
            let tile = self._supply(@game, ref player, @tile, supply);

            // [Effect] Update tile
            store.set_tile(tile);

            // [Effect] Update player
            store.set_player(player);
        }

        fn transfer(
            self: @ContractState,
            world: IWorldDispatcher,
            game_id: u32,
            source_index: u8,
            target_index: u8,
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
            let source = store.tile(game, source_index);
            let target = store.tile(game, target_index);
            assert(source.owner == player.index.into(), errors::TRANSFER_INVALID_OWNER);

            // [Compute] Transfer
            let tiles = store.tiles(game).span();
            let (source, target) = self._transfer(@game, @source, @target, tiles, army);

            // [Effect] Update tiles
            store.set_tile(source);
            store.set_tile(target);
        }
    }

    #[generate_trait]
    impl Internal of InternalTrait {
        fn _attack(
            self: @ContractState, game: @Game, attacker: @Tile, defender: @Tile, dispatched: u32
        ) -> Span<Tile> {
            let mut attacker_land = LandTrait::load(attacker);
            let mut defender_land = LandTrait::load(defender);
            let order = get_tx_info().unbox().transaction_hash;
            attacker_land.attack(dispatched, ref defender_land, order);
            array![attacker_land.dump(*game.id), defender_land.dump(*game.id)].span()
        }

        fn _defend(
            self: @ContractState, game: @Game, ref player: Player, attacker: @Tile, defender: @Tile
        ) -> Span<Tile> {
            let mut attacker_land = LandTrait::load(attacker);
            let mut defender_land = LandTrait::load(defender);
            let order = get_tx_info().unbox().transaction_hash;
            defender_land.defend(ref attacker_land, *game.seed, order);

            if defender_land.defeated && !player.conqueror {
                player.conqueror = true;
            };

            array![attacker_land.dump(*game.id), defender_land.dump(*game.id)].span()
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
                    Option::None => { break; },
                };
            };
            tiles.span()
        }

        fn _supply(
            self: @ContractState, game: @Game, ref player: Player, tile: @Tile, supply: u32
        ) -> Tile {
            // [Check] Tile owner
            assert(tile.owner == @player.index.into(), errors::SUPPLY_INVALID_OWNER);

            // [Compute] Supply
            let mut land = LandTrait::load(tile);
            land.supply(ref player, supply);

            // [Return] Update tile
            land.dump(*game.id)
        }

        fn _transfer(
            self: @ContractState,
            game: @Game,
            source: @Tile,
            target: @Tile,
            mut tiles: Span<Tile>,
            army: u32
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
                    Option::None => { break; },
                };
            };
            let mut from = LandTrait::load(source);
            let mut to = LandTrait::load(target);
            from.transfer(ref to, army, lands.span());
            (from.dump(*game.id), to.dump(*game.id))
        }
    }
}
