// Core imports

use debug::PrintTrait;

// Starknet imports

use starknet::testing::set_contract_address;

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports

use zrisk::components::game::{Game, GameTrait, Turn};
use zrisk::components::player::Player;
use zrisk::components::tile::Tile;
use zrisk::tests::setup::setup;

// Constants

const ACCOUNT: felt252 = 'ACCOUNT';
const SEED: felt252 = 'SEED';
const NAME: felt252 = 'NAME';
const PLAYER_COUNT: u8 = 4;
const PLAYER_INDEX: u32 = 0;

#[test]
#[available_gas(1_000_000_000)]
fn test_finish() {
    // [Setup]
    let world = setup::spawn_game();

    // [Create]
    world.execute('create', array![ACCOUNT, SEED, NAME, PLAYER_COUNT.into()]);

    // [Assert] Game
    let game: Game = get!(world, ACCOUNT, (Game));
    assert(game.player() == 0, 'Game: wrong player index 0');
    assert(game.turn() == Turn::Supply, 'Game: wrong turn 0');

    // [Compute] Tile army and player available supply
    let player_key = (game.id, PLAYER_INDEX);
    let player: Player = get!(world, player_key.into(), (Player));
    let supply: felt252 = player.supply.into();
    let mut tile_index: felt252 = 1;
    loop {
        let tile: Tile = get!(world, (game.id, tile_index).into(), (Tile));
        if tile.owner == PLAYER_INDEX {
            break;
        }
        tile_index += 1;
    };

    // [Supply]
    world.execute('supply', array![ACCOUNT, tile_index, supply]);

    // [Finish]
    world.execute('finish', array![ACCOUNT]);

    // [Assert] Game
    let game: Game = get!(world, ACCOUNT, (Game));
    assert(game.player() == 0, 'Game: wrong player index 1');
    assert(game.turn() == Turn::Attack, 'Game: wrong turn 1');

    // [Finish]
    world.execute('finish', array![ACCOUNT]);

    // [Assert] Game
    let game: Game = get!(world, ACCOUNT, (Game));
    assert(game.player() == 0, 'Game: wrong player index 2');
    assert(game.turn() == Turn::Transfer, 'Game: wrong turn 2');

    // [Finish]
    world.execute('finish', array![ACCOUNT]);

    // [Assert] Game
    let game: Game = get!(world, ACCOUNT, (Game));
    assert(game.player() == 1, 'Game: wrong player index 3');
    assert(game.turn() == Turn::Supply, 'Game: wrong turn 3');

    // [Assert] Player
    let player: Player = get!(world, (game.id, game.player()).into(), (Player));
    assert(player.supply > 0, 'Player: wrong supply');
}

#[test]
#[available_gas(1_000_000_000)]
#[should_panic(
    expected: (
        'Finish: invalid supply', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED',
    )
)]
fn test_finish_revert_invalid_supply() {
    // [Setup]
    let world = setup::spawn_game();

    // [Create]
    world.execute('create', array![ACCOUNT, SEED, NAME, PLAYER_COUNT.into()]);

    // [Finish]
    world.execute('finish', array![ACCOUNT]);
}

#[test]
#[available_gas(1_000_000_000)]
#[should_panic(
    expected: (
        'Finish: invalid player', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED',
    )
)]
fn test_finish_revert_invalid_player() {
    // [Setup]
    let world = setup::spawn_game();

    // [Create]
    world.execute('create', array![ACCOUNT, SEED, NAME, PLAYER_COUNT.into()]);

    // [Assert] Game
    let game: Game = get!(world, ACCOUNT, (Game));
    assert(game.player() == 0, 'Game: wrong player index 0');
    assert(game.turn() == Turn::Supply, 'Game: wrong turn 0');

    // [Finish]
    set_contract_address(starknet::contract_address_const::<1>());
    world.execute('finish', array![ACCOUNT]);
}
