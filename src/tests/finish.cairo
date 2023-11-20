// Core imports

use debug::PrintTrait;

// Starknet imports

use starknet::testing::set_contract_address;

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports

use zconqueror::config;
use zconqueror::store::{Store, StoreTrait};
use zconqueror::components::game::{Game, GameTrait, Turn};
use zconqueror::components::player::Player;
use zconqueror::components::tile::Tile;
use zconqueror::systems::player::IActionsDispatcherTrait;
use zconqueror::tests::setup::{setup, setup::Systems};

// Constants

const ACCOUNT: felt252 = 'ACCOUNT';
const SEED: felt252 = 'BANG';
const NAME: felt252 = 'NAME';
const PLAYER_COUNT: u8 = 4;
const PLAYER_INDEX: u8 = 0;

#[test]
#[available_gas(1_000_000_000)]
fn test_finish_next_player() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    systems.player_actions.create(world, ACCOUNT, SEED, NAME, PLAYER_COUNT);

    // [Assert] Game
    let game: Game = store.game(ACCOUNT);
    assert(game.player() == 0, 'Game: wrong player index 0');
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
    systems.player_actions.supply(world, ACCOUNT, tile_index, supply);

    // [Finish]
    systems.player_actions.finish(world, ACCOUNT);

    // [Assert] Game
    let game: Game = store.game(ACCOUNT);
    assert(game.player() == 0, 'Game: wrong player index 1');
    assert(game.turn() == Turn::Attack, 'Game: wrong turn 1');

    // [Finish]
    systems.player_actions.finish(world, ACCOUNT);

    // [Assert] Game
    let game: Game = store.game(ACCOUNT);
    assert(game.player() == 0, 'Game: wrong player index 2');
    assert(game.turn() == Turn::Transfer, 'Game: wrong turn 2');

    // [Finish]
    systems.player_actions.finish(world, ACCOUNT);

    // [Assert] Game
    let game: Game = store.game(ACCOUNT);
    assert(game.player() == 0, 'Game: wrong player index 3');
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
    systems.player_actions.create(world, ACCOUNT, SEED, NAME, PLAYER_COUNT);

    // [Finish]
    systems.player_actions.finish(world, ACCOUNT);
}

#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Finish: invalid player', 'ENTRYPOINT_FAILED',))]
fn test_finish_revert_invalid_player() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    systems.player_actions.create(world, ACCOUNT, SEED, NAME, PLAYER_COUNT);

    // [Assert] Game
    let game: Game = store.game(ACCOUNT);
    assert(game.player() == 0, 'Game: wrong player index 0');
    assert(game.turn() == Turn::Supply, 'Game: wrong turn 0');

    // [Finish]
    set_contract_address(starknet::contract_address_const::<1>());
    systems.player_actions.finish(world, ACCOUNT);
}
