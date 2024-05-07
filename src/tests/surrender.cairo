// Core imports

use core::debug::PrintTrait;

// Starknet imports

use starknet::testing::set_contract_address;

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports

use zconqueror::config;
use zconqueror::store::{Store, StoreTrait};
use zconqueror::models::game::{Game, GameTrait, Turn};
use zconqueror::models::player::Player;
use zconqueror::models::tile::Tile;
use zconqueror::systems::host::IHostDispatcherTrait;
use zconqueror::systems::play::IPlayDispatcherTrait;
use zconqueror::tests::setup::{setup, setup::{Systems, Context, HOST, PLAYER, ANYONE}};

// Constants

const HOST_NAME: felt252 = 'HOST';
const PLAYER_NAME: felt252 = 'PLAYER';
const ANYONE_NAME: felt252 = 'ANYONE';
const PRICE: u256 = 1_000_000_000_000_000_000;
const PENALTY: u64 = 60;
const PLAYER_COUNT: u8 = 2;
const PLAYER_INDEX: u32 = 0;
const ROUND_COUNT: u32 = 10;

#[test]
#[available_gas(1_000_000_000)]
fn test_surrender_player_quits() {
    // [Setup]
    let (world, systems, _) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    let game_id = systems.host.create(world, HOST_NAME, PRICE, PENALTY);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);
    set_contract_address(HOST());
    systems.host.start(world, game_id, ROUND_COUNT);

    // [Banish]
    set_contract_address(PLAYER());
    systems.play.surrender(world, game_id);

    // [Assert] Game
    let game: Game = store.game(game_id);
    assert(game.over, 'Game: wrong over status');
}

#[test]
#[available_gas(1_000_000_000)]
fn test_surrender_host_quits() {
    // [Setup]
    let (world, systems, _) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    let game_id = systems.host.create(world, HOST_NAME, PRICE, PENALTY);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);
    set_contract_address(HOST());
    systems.host.start(world, game_id, ROUND_COUNT);

    // [Banish]
    set_contract_address(HOST());
    systems.play.surrender(world, game_id);

    // [Assert] Game
    let game: Game = store.game(game_id);
    assert(game.over, 'Game: wrong over status');
}

#[test]
#[available_gas(1_000_000_000)]
fn test_surrender_3_players_player_quits() {
    // [Setup]
    let (world, systems, _) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    let game_id = systems.host.create(world, HOST_NAME, PRICE, PENALTY);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);
    set_contract_address(ANYONE());
    systems.host.join(world, game_id, ANYONE_NAME);
    set_contract_address(HOST());
    systems.host.start(world, game_id, ROUND_COUNT);

    // [Banish]
    set_contract_address(PLAYER());
    systems.play.surrender(world, game_id);

    // [Assert] Game
    let game: Game = store.game(game_id);
    assert(!game.over, 'Game: wrong over status');
}

#[test]
#[available_gas(1_000_000_000)]
fn test_surrender_3_players_host_quits() {
    // [Setup]
    let (world, systems, _) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    let game_id = systems.host.create(world, HOST_NAME, PRICE, PENALTY);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);
    set_contract_address(ANYONE());
    systems.host.join(world, game_id, ANYONE_NAME);
    set_contract_address(HOST());
    systems.host.start(world, game_id, ROUND_COUNT);

    // [Banish]
    set_contract_address(HOST());
    systems.play.surrender(world, game_id);

    // [Assert] Game
    let game: Game = store.game(game_id);
    assert(!game.over, 'Game: wrong over status');
}

#[test]
#[available_gas(1_000_000_000)]
fn test_surrender_3_players_anyone_quits() {
    // [Setup]
    let (world, systems, _) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    let game_id = systems.host.create(world, HOST_NAME, PRICE, PENALTY);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);
    set_contract_address(ANYONE());
    systems.host.join(world, game_id, ANYONE_NAME);
    set_contract_address(HOST());
    systems.host.start(world, game_id, ROUND_COUNT);

    // [Banish]
    set_contract_address(ANYONE());
    systems.play.surrender(world, game_id);

    // [Assert] Game
    let game: Game = store.game(game_id);
    assert(!game.over, 'Game: wrong over status');
}

#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Game: not started', 'ENTRYPOINT_FAILED',))]
fn test_surrender_revert_game_not_started() {
    // [Setup]
    let (world, systems, _) = setup::spawn_game();

    // [Create]
    let game_id = systems.host.create(world, HOST_NAME, PRICE, PENALTY);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);

    // [Banish]
    set_contract_address(PLAYER());
    systems.play.surrender(world, game_id);
}

#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Game: is over', 'ENTRYPOINT_FAILED',))]
fn test_banish_revert_game_is_over() {
    // [Setup]
    let (world, systems, _) = setup::spawn_game();

    // [Create]
    let game_id = systems.host.create(world, HOST_NAME, PRICE, PENALTY);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);
    set_contract_address(HOST());
    systems.host.start(world, game_id, ROUND_COUNT);

    // [Banish]
    set_contract_address(PLAYER());
    systems.play.surrender(world, game_id);
    systems.play.surrender(world, game_id);
}
