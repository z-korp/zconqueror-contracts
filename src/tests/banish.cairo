// Core imports

use debug::PrintTrait;

// Starknet imports

use starknet::testing::{set_contract_address, set_block_timestamp};

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
const PENALITY: u64 = 60;
const PLAYER_COUNT: u8 = 2;
const PLAYER_INDEX: u32 = 0;

#[test]
#[available_gas(1_000_000_000)]
fn test_banish_2_players() {
    // [Setup]
    let (world, systems, _) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    set_block_timestamp(1000);
    let game_id = systems.host.create(world, HOST_NAME, PRICE, PENALITY);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);
    set_contract_address(HOST());
    systems.host.start(world, game_id);

    // [Banish]
    set_contract_address(PLAYER());
    let game: Game = store.game(game_id);
    set_block_timestamp(game.clock + PENALITY + 1);
    let player: Player = store.current_player(game);
    systems.play.banish(world, game_id, player.index);

    // [Assert] Game
    let game: Game = store.game(game_id);
    assert(game.over, 'Game: wrong over status');
}

#[test]
#[available_gas(1_000_000_000)]
fn test_banish_3_players() {
    // [Setup]
    let (world, systems, _) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    set_block_timestamp(1000);
    let game_id = systems.host.create(world, HOST_NAME, PRICE, PENALITY);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);
    set_contract_address(ANYONE());
    systems.host.join(world, game_id, ANYONE_NAME);
    set_contract_address(HOST());
    systems.host.start(world, game_id);

    // [Banish]
    set_contract_address(PLAYER());
    let game: Game = store.game(game_id);
    set_block_timestamp(game.clock + PENALITY + 1);
    let player: Player = store.current_player(game);
    systems.play.banish(world, game_id, player.index);

    // [Assert] Game
    let game: Game = store.game(game_id);
    assert(!game.over, 'Game: wrong over status');
}

#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Game: not started', 'ENTRYPOINT_FAILED',))]
fn test_banish_revert_game_not_started() {
    // [Setup]
    let (world, systems, _) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    set_block_timestamp(1000);
    let game_id = systems.host.create(world, HOST_NAME, PRICE, PENALITY);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);

    // [Banish]
    set_contract_address(PLAYER());
    let game: Game = store.game(game_id);
    set_block_timestamp(game.clock + PENALITY + 1);
    let player: Player = store.current_player(game);
    systems.play.banish(world, game_id, player.index);
}

#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Banish: invalid condition', 'ENTRYPOINT_FAILED',))]
fn test_banish_revert_invalid_condition() {
    // [Setup]
    let (world, systems, _) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    set_block_timestamp(1000);
    let game_id = systems.host.create(world, HOST_NAME, PRICE, PENALITY);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);
    set_contract_address(HOST());
    systems.host.start(world, game_id);

    // [Banish]
    set_contract_address(PLAYER());
    let game: Game = store.game(game_id);
    set_block_timestamp(game.clock + PENALITY - 1);
    let player: Player = store.current_player(game);
    systems.play.banish(world, game_id, player.index);
}

#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Game: is over', 'ENTRYPOINT_FAILED',))]
fn test_banish_revert_game_is_over() {
    // [Setup]
    let (world, systems, _) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    set_block_timestamp(1000);
    let game_id = systems.host.create(world, HOST_NAME, PRICE, PENALITY);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);
    set_contract_address(HOST());
    systems.host.start(world, game_id);

    // [Banish]
    set_contract_address(PLAYER());
    let game: Game = store.game(game_id);
    set_block_timestamp(game.clock + PENALITY + 1);
    let player: Player = store.current_player(game);
    systems.play.banish(world, game_id, player.index);
    systems.play.banish(world, game_id, player.index);
}
