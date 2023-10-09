// Core imports

use debug::PrintTrait;

// Starknet imports

use starknet::testing::{set_contract_address, set_transaction_hash};

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports

use zrisk::config;
use zrisk::datastore::{DataStore, DataStoreTrait};
use zrisk::components::game::{Game, GameTrait};
use zrisk::components::player::Player;
use zrisk::components::tile::Tile;
use zrisk::systems::player::IActionsDispatcherTrait;
use zrisk::tests::setup::{setup, setup::Systems};

// Constants

const ACCOUNT: felt252 = 'ACCOUNT';
const SEED: felt252 = 'SEED';
const NAME: felt252 = 'NAME';
const PLAYER_COUNT: u8 = 2;
const PLAYER_INDEX: u8 = 0;

#[test]
#[available_gas(1_000_000_000)]
fn test_defend() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    systems.player_actions.create(world, ACCOUNT, SEED, NAME, PLAYER_COUNT);

    // [Compute] Attacker tile
    let game: Game = datastore.game(ACCOUNT);
    let initial_player: Player = datastore.player(game, PLAYER_INDEX);
    let supply = initial_player.supply.into();
    let mut attacker = 1;
    let army = loop {
        let tile: Tile = datastore.tile(game, attacker.into());
        if tile.owner == PLAYER_INDEX.into() {
            break tile.army;
        }
        attacker += 1;
    };

    // [Supply]
    systems.player_actions.supply(world, ACCOUNT, attacker, supply);

    // [Finish]
    systems.player_actions.finish(world, ACCOUNT);

    // [Compute] Defender tile
    let mut neighbors = config::neighbors(attacker).expect('Attack: invalid tile id');
    let mut defender = loop {
        match neighbors.pop_front() {
            Option::Some(index) => {
                let tile: Tile = datastore.tile(game, *index);
                if tile.owner != PLAYER_INDEX.into() {
                    break tile.index;
                }
            },
            Option::None => { panic(array!['Attack: defender not found']); },
        };
    };

    // [Attack]
    set_transaction_hash('ATTACK');
    let distpached: u32 = (army + supply - 1).into();
    systems.player_actions.attack(world, ACCOUNT, attacker, defender, distpached);

    // [Defend]
    set_transaction_hash('DEFEND');
    systems.player_actions.defend(world, ACCOUNT, attacker, defender);
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Land: invalid order status', 'ENTRYPOINT_FAILED',))]
fn test_defend_revert_invalid_order() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    systems.player_actions.create(world, ACCOUNT, SEED, NAME, PLAYER_COUNT);

    // [Compute] Attacker tile
    let game: Game = datastore.game(ACCOUNT);
    let initial_player: Player = datastore.player(game, PLAYER_INDEX);
    let supply = initial_player.supply.into();
    let mut attacker = 1;
    let army = loop {
        let tile: Tile = datastore.tile(game, attacker.into());
        if tile.owner == PLAYER_INDEX.into() {
            break tile.army;
        }
        attacker += 1;
    };

    // [Supply]
    systems.player_actions.supply(world, ACCOUNT, attacker, supply);

    // [Finish]
    systems.player_actions.finish(world, ACCOUNT);

    // [Compute] Defender tile
    let mut neighbors = config::neighbors(attacker).expect('Attack: invalid tile id');
    let mut defender = loop {
        match neighbors.pop_front() {
            Option::Some(index) => {
                let tile: Tile = datastore.tile(game, *index);
                if tile.owner != PLAYER_INDEX.into() {
                    break tile.index;
                }
            },
            Option::None => { panic(array!['Attack: defender not found']); },
        };
    };

    // [Attack]
    set_transaction_hash('ORDER');
    let distpached: u32 = (army + supply - 1).into();
    systems.player_actions.attack(world, ACCOUNT, attacker, defender, distpached);

    // [Defend]
    set_transaction_hash('ORDER');
    systems.player_actions.defend(world, ACCOUNT, attacker, defender);
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Defend: invalid player', 'ENTRYPOINT_FAILED',))]
fn test_defend_revert_invalid_player() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    systems.player_actions.create(world, ACCOUNT, SEED, NAME, PLAYER_COUNT);

    // [Compute] Tile army and player available supply
    let game: Game = datastore.game(ACCOUNT);
    let initial_player: Player = datastore.player(game, PLAYER_INDEX);
    let supply: u32 = initial_player.supply.into();
    let mut tile_index: u8 = 1;
    loop {
        let tile: Tile = datastore.tile(game, tile_index);
        if tile.owner == PLAYER_INDEX.into() {
            break;
        }
        tile_index += 1;
    };

    // [Supply]
    systems.player_actions.supply(world, ACCOUNT, tile_index, supply);

    // [Finish]
    systems.player_actions.finish(world, ACCOUNT);

    // [Defend]
    set_contract_address(starknet::contract_address_const::<1>());
    systems.player_actions.defend(world, ACCOUNT, 0, 0);
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Defend: invalid owner', 'ENTRYPOINT_FAILED',))]
fn test_defend_revert_invalid_owner() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    systems.player_actions.create(world, ACCOUNT, SEED, NAME, PLAYER_COUNT);

    // [Compute] Tile army and player available supply
    let game: Game = datastore.game(ACCOUNT);
    let initial_player: Player = datastore.player(game, PLAYER_INDEX);
    let supply: u32 = initial_player.supply.into();
    let mut tile_index: u8 = 1;
    loop {
        let tile: Tile = datastore.tile(game, tile_index);
        if tile.owner == PLAYER_INDEX.into() {
            break;
        }
        tile_index += 1;
    };

    // [Supply]
    systems.player_actions.supply(world, ACCOUNT, tile_index, supply);

    // [Finish]
    systems.player_actions.finish(world, ACCOUNT);

    // [Compute] Invalid owned tile
    let game: Game = datastore.game(ACCOUNT);
    let mut index = 1;
    loop {
        let tile: Tile = datastore.tile(game, index);
        if tile.owner != PLAYER_INDEX.into() {
            break;
        }
        index += 1;
    };

    // [Defend]
    systems.player_actions.defend(world, ACCOUNT, index, 0);
}

