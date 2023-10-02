// Core imports

use traits::{Into, TryInto};
use core::result::ResultTrait;
use array::{ArrayTrait, SpanTrait};
use option::OptionTrait;
use box::BoxTrait;
use clone::Clone;
use debug::PrintTrait;

// Starknet imports

use starknet::testing::set_contract_address;

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports

use zrisk::components::game::{Game, GameTrait};
use zrisk::components::player::Player;
use zrisk::components::tile::Tile;
use zrisk::tests::setup::setup;

// Constants

const ACCOUNT: felt252 = 'ACCOUNT';
const SEED: felt252 = 'SEED';
const NAME: felt252 = 'NAME';
const PLAYER_COUNT: u8 = 2;
const PLAYER_INDEX: u32 = 0;

#[test]
#[available_gas(1_000_000_000)]
fn test_supply() {
    // [Setup]
    let world = setup::spawn_game();

    // [Create]
    world.execute('create', array![ACCOUNT, SEED, NAME, PLAYER_COUNT.into()]);

    // [Compute] Tile army and player available supply
    let game: Game = get!(world, ACCOUNT, (Game));
    let initial_player: Player = get!(world, (game.id, PLAYER_INDEX).into(), (Player));
    let supply = initial_player.supply.into();
    let mut tile_index = 1;
    let army = loop {
        let tile: Tile = get!(world, (game.id, tile_index).into(), (Tile));
        if tile.owner == PLAYER_INDEX {
            break tile.army;
        }
        tile_index += 1;
    };

    // [Supply]
    world.execute('supply', array![ACCOUNT, tile_index.into(), supply.into()]);

    // [Assert] Player supply
    let player: Player = get!(world, (game.id, PLAYER_INDEX).into(), (Player));
    assert(player.supply == 0, 'Player: wrong supply');

    // [Assert] Tile supplied
    let tile: Tile = get!(world, (game.id, tile_index).into(), (Tile));
    assert(tile.army == army + supply, 'Tile: wrong army');
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(
    expected: (
        'Supply: invalid player', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED',
    )
)]
fn test_supply_invalid_player() {
    // [Setup]
    let world = setup::spawn_game();

    // [Create]
    world.execute('create', array![ACCOUNT, SEED, NAME, PLAYER_COUNT.into()]);

    // [Supply]
    set_contract_address(starknet::contract_address_const::<1>());
    world.execute('supply', array![ACCOUNT, 0, 0]);
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(
    expected: (
        'Supply: invalid owner', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED',
    )
)]
fn test_supply_invalid_owner() {
    // [Setup]
    let world = setup::spawn_game();

    // [Create]
    world.execute('create', array![ACCOUNT, SEED, NAME, PLAYER_COUNT.into()]);

    // [Compute] Invalid owned tile
    let game: Game = get!(world, ACCOUNT, (Game));
    let mut index = 1;
    loop {
        let tile: Tile = get!(world, (game.id, index).into(), (Tile));
        if tile.owner != PLAYER_INDEX {
            break;
        }
        index += 1;
    };

    // [Transfer]
    world.execute('supply', array![ACCOUNT, index.into(), 0]);
}
