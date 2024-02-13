// Core imports

use debug::PrintTrait;

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
use zconqueror::tests::setup::{setup, setup::{Systems, HOST, PLAYER}};

// Constants

const HOST_NAME: felt252 = 'HOST';
const PLAYER_NAME: felt252 = 'PLAYER';
const PRICE: u256 = 1_000_000_000_000_000_000;
const PLAYER_COUNT: u8 = 2;
const PLAYER_INDEX: u8 = 0;

#[test]
#[available_gas(1_000_000_000)]
fn test_finish_next_player() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    let game_id = systems.host.create(world, HOST_NAME, PRICE);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);
    set_contract_address(HOST());
    systems.host.start(world, game_id);

    // [Assert] Game
    let game: Game = store.game(game_id);
    assert(game.player() == PLAYER_INDEX, 'Game: wrong player index 0');
    assert(game.turn() == Turn::Supply, 'Game: wrong turn 0');

    // [Compute] Tile army and player available supply
    let player: Player = store.player(game, PLAYER_INDEX);
    let supply: u32 = player.supply.into();
    let mut tile_index: u8 = 1;
    loop {
        let tile: Tile = store.tile(game, tile_index);
        if tile.owner == PLAYER_INDEX.into() {
            break;
        }
        tile_index += 1;
    };

    // [Supply]
    set_contract_address(player.address);
    systems.play.supply(world, game_id, tile_index, supply);

    // [Finish]
    systems.play.finish(world, game_id);

    // [Assert] Game
    let game: Game = store.game(game_id);
    assert(game.player() == PLAYER_INDEX, 'Game: wrong player index 1');
    assert(game.turn() == Turn::Attack, 'Game: wrong turn 1');

    // [Finish]
    systems.play.finish(world, game_id);

    // [Assert] Game
    let game: Game = store.game(game_id);
    assert(game.player() == PLAYER_INDEX, 'Game: wrong player index 2');
    assert(game.turn() == Turn::Transfer, 'Game: wrong turn 2');

    // [Finish]
    systems.play.finish(world, game_id);

    // [Assert] Game
    let game: Game = store.game(game_id);
    let player_index = 1 - PLAYER_INDEX;
    assert(game.player() == player_index, 'Game: wrong player index 3');
    assert(game.turn() == Turn::Supply, 'Game: wrong turn 3');

    // [Assert] Player
    let player: Player = store.player(game, game.player());
    assert(player.supply > 0, 'Player: wrong supply');
}

#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Finish: invalid supply', 'ENTRYPOINT_FAILED',))]
fn test_finish_revert_invalid_supply() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    let game_id = systems.host.create(world, HOST_NAME, PRICE);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);
    set_contract_address(HOST());
    systems.host.start(world, game_id);

    // [Finish]
    let game: Game = store.game(game_id);
    let player: Player = store.player(game, PLAYER_INDEX);
    set_contract_address(player.address);
    systems.play.finish(world, game_id);
}

#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Finish: invalid player', 'ENTRYPOINT_FAILED',))]
fn test_finish_revert_invalid_player() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    let game_id = systems.host.create(world, HOST_NAME, PRICE);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);
    set_contract_address(HOST());
    systems.host.start(world, game_id);

    // [Assert] Game
    let game: Game = store.game(game_id);
    assert(game.player() == 0, 'Game: wrong player index 0');
    assert(game.turn() == Turn::Supply, 'Game: wrong turn 0');

    // [Finish]
    let player_index = 1 - PLAYER_INDEX;
    let player: Player = store.player(game, player_index);
    set_contract_address(player.address);
    systems.play.finish(world, game_id);
}
