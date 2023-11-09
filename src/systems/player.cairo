// Dojo imports

use dojo::world::IWorldDispatcher;

// System trait

#[starknet::interface]
trait IActions<TContractState> {
    fn create(
        self: @TContractState,
        world: IWorldDispatcher,
        account: felt252,
        seed: felt252,
        name: felt252,
        player_count: u8
    );
    fn attack(
        self: @TContractState,
        world: IWorldDispatcher,
        account: felt252,
        attacker_index: u8,
        defender_index: u8,
        dispatched: u32
    );
    fn defend(
        self: @TContractState,
        world: IWorldDispatcher,
        account: felt252,
        attacker_index: u8,
        defender_index: u8
    );
    fn discard(
        self: @TContractState,
        world: IWorldDispatcher,
        account: felt252,
        card_one: u8,
        card_two: u8,
        card_three: u8
    );
    fn finish(self: @TContractState, world: IWorldDispatcher, account: felt252);
    fn supply(
        self: @TContractState,
        world: IWorldDispatcher,
        account: felt252,
        tile_index: u8,
        supply: u32
    );
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
mod actions {
    // Starknet imports

    use starknet::{get_tx_info, get_caller_address};

    // Dojo imports

    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // Components imports

    use zrisk::components::game::{Game, GameTrait, Turn};
    use zrisk::components::player::{Player, PlayerTrait};
    use zrisk::components::tile::Tile;

    // Entities imports

    use zrisk::entities::deck::DeckTrait;
    use zrisk::entities::hand::HandTrait;
    use zrisk::entities::land::{Land, LandTrait};
    use zrisk::entities::map::{Map, MapTrait};
    use zrisk::entities::set::SetTrait;

    // Internal imports

    use zrisk::constants::ZERO;
    use zrisk::config::{TILE_NUMBER, ARMY_NUMBER};
    use zrisk::datastore::{DataStore, DataStoreTrait};
    use zrisk::bot::simple::SimpleTrait;

    // Local imports

    use super::IActions;

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
    impl Actions of IActions<ContractState> {
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
                        Option::None => { break; },
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
                        game_id, player_index.into(), address: ZERO(), name: card.into()
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

            // [Effect] Play bots until real player
            let player = datastore.current_player(game);
            if player.address.is_zero() {
                self.finish(world, account);
            };
        }

        fn attack(
            self: @ContractState,
            world: IWorldDispatcher,
            account: felt252,
            attacker_index: u8,
            defender_index: u8,
            dispatched: u32
        ) {
            // [Setup] Datastore
            let mut datastore: DataStore = DataStoreTrait::new(world);

            // [Check] Turn
            let mut game: Game = datastore.game(account);
            assert(game.turn() == Turn::Attack, errors::ATTACK_INVALID_TURN);

            // [Check] Caller is player
            let caller = get_caller_address();
            let mut player = datastore.current_player(game);
            assert(caller == player.address, errors::ATTACK_INVALID_PLAYER);

            // [Check] Tiles owner
            let attacker_tile = datastore.tile(game, attacker_index);
            let defender_tile = datastore.tile(game, defender_index);
            assert(attacker_tile.owner == player.index.into(), errors::ATTACK_INVALID_OWNER);

            // [Compute] Attack
            let tiles = self._attack(@game, @attacker_tile, @defender_tile, dispatched);

            // [Effect] Update tiles
            datastore.set_tiles(tiles);
        }

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
            assert(game.turn() == Turn::Attack, errors::DEFEND_INVALID_TURN);

            // [Check] Caller is player
            let caller = get_caller_address();
            let mut player = datastore.current_player(game);
            assert(caller == player.address, errors::DEFEND_INVALID_PLAYER);

            // [Check] Tiles owner
            let attacker_tile = datastore.tile(game, attacker_index);
            let defender_tile = datastore.tile(game, defender_index);
            assert(attacker_tile.owner == player.index.into(), errors::DEFEND_INVALID_OWNER);

            // [Compute] Defend
            let tiles = self._defend(@game, ref player, @attacker_tile, @defender_tile);

            // [Effect] Update tiles
            datastore.set_tiles(tiles);

            // [Effect] Update player
            datastore.set_player(player);
        }

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
            assert(game.turn() == Turn::Supply, errors::DISCARD_INVALID_TURN);

            // [Check] Caller is player
            let caller = get_caller_address();
            let mut player = datastore.current_player(game);
            assert(caller == player.address, errors::DISCARD_INVALID_PLAYER);

            // [Compute] Discard
            let tiles = datastore.tiles(game);
            let tiles = self._discard(@game, ref player, tiles, card_one, card_two, card_three);

            // [Effect] Update tiles
            datastore.set_tiles(tiles);

            // [Effect] Update player
            datastore.set_player(player);
        }

        fn finish(self: @ContractState, world: IWorldDispatcher, account: felt252) {
            // [Setup] Datastore
            let mut datastore: DataStore = DataStoreTrait::new(world);

            // [Check] Caller is player
            let caller = get_caller_address();
            let mut game: Game = datastore.game(account);
            let mut player = datastore.current_player(game);
            assert(
                caller == player.address || player.address.is_zero(), errors::FINISH_INVALID_PLAYER
            );

            // [Compute] Finish
            let tiles = datastore.tiles(game);

            // [Check] Player is a bot
            let player_count = game.player_count;
            if player.address.is_zero() {
                let mut map = MapTrait::from_tiles(player_count.into(), tiles);
                let score = map.score(player.index);

                // [Check] Bot is not dead
                if 0 != score.into() {
                    // [Compute] Bot actions
                    let (new_player, new_tiles) = SimpleTrait::supply(game, player, tiles);
                    // [Effect] Update components
                    datastore.set_player(new_player);
                    datastore.set_tiles(new_tiles);
                }

                // [Compute] Game turn
                game.roll();
                game.decrement();
                datastore.set_game(game);
            }

            // [Check] Player supply is empty
            let player = datastore.current_player(game);
            assert(player.supply == 0, errors::FINISH_INVALID_SUPPLY);

            // [Command] Update next player supply if next turn is supply
            if game.next_turn() == Turn::Supply {
                // [Compute] Draw card if conqueror
                // TODO

                // [Compute] Update player
                let mut map = MapTrait::from_tiles(player_count.into(), tiles);
                let mut next_player = datastore.next_player(game);
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
                datastore.set_player(next_player);

                // [Check] If next next player is a bot, operate recursive iteration
                if next_player.address.is_zero() {
                    game.increment();
                    datastore.set_game(game);
                    return self.finish(world, account);
                }
            }

            // [Effect] Update game
            game.increment();
            datastore.set_game(game);
        }

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
            assert(game.turn() == Turn::Supply, errors::SUPPLY_INVALID_TURN);

            // [Check] Caller is player
            let caller = get_caller_address();
            let mut player = datastore.current_player(game);
            assert(caller == player.address, errors::SUPPLY_INVALID_PLAYER);

            // [Compute] Supply
            let tile = datastore.tile(game, tile_index.into());
            let tile = self._supply(@game, ref player, @tile, supply);

            // [Effect] Update tile
            datastore.set_tile(tile);

            // [Effect] Update player
            datastore.set_player(player);
        }

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
            assert(game.turn() == Turn::Transfer, errors::TRANSFER_INVALID_TURN);

            // [Check] Caller is player
            let caller = get_caller_address();
            let mut player = datastore.current_player(game);
            assert(caller == player.address, errors::TRANSFER_INVALID_PLAYER);

            // [Check] Tiles owner
            let source = datastore.tile(game, source_index);
            let target = datastore.tile(game, target_index);
            assert(source.owner == player.index.into(), errors::TRANSFER_INVALID_OWNER);

            // [Compute] Transfer
            let tiles = datastore.tiles(game);
            let (source, target) = self._transfer(@game, @source, @target, tiles, army);

            // [Effect] Update tiles
            datastore.set_tile(source);
            datastore.set_tile(target);
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
