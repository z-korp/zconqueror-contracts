// Core imports

use debug::PrintTrait;

// Starknet imports

use starknet::testing::set_contract_address;

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports

use zrisk::config::TILE_NUMBER;
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
fn test_transfer() {
    // [Setup]
    let world = setup::spawn_game();

    // [Create]
    world.execute('create', array![ACCOUNT, SEED, NAME, PLAYER_COUNT.into()]);

    // [Compute] Tile army and player available supply
    let game: Game = get!(world, ACCOUNT, (Game));
    let initial_player: Player = get!(world, (game.id, PLAYER_INDEX).into(), (Player));
    let supply: felt252 = initial_player.supply.into();
    let mut tile_index = 1;
    loop {
        let tile: Tile = get!(world, (game.id, tile_index).into(), (Tile));
        if tile.owner == PLAYER_INDEX {
            break tile.army;
        }
        tile_index += 1;
    };

    // [Supply]
    world.execute('supply', array![ACCOUNT, tile_index.into(), supply.into()]);

    // [Compute] First 2 owned tiles
    let mut tiles: Array<Tile> = array![];
    let mut tile_index = 1;
    loop {
        if tile_index > TILE_NUMBER || tiles.len() == 2 {
            break;
        };
        let tile: Tile = get!(world, (game.id, tile_index).into(), (Tile));
        if tile.owner == PLAYER_INDEX {
            tiles.append(tile);
        }
        tile_index += 1;
    };

    // [Transfer]
    let source = tiles.pop_front().unwrap();
    let target = tiles.pop_front().unwrap();
    let army = source.army - 1;
    world
        .execute(
            'transfer', array![ACCOUNT, source.index.into(), target.index.into(), army.into()]
        );

    // [Assert] Source army
    let tile: Tile = get!(world, (game.id, source.index).into(), (Tile));
    assert(tile.army == 1, 'Tile: wrong source army');

    // [Assert] Target army
    let tile: Tile = get!(world, (game.id, target.index).into(), (Tile));
    assert(tile.army == target.army + army, 'Tile: wrong target army');
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(
    expected: (
        'Transfer: invalid player', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED',
    )
)]
fn test_transfer_revert_invalid_player() {
    // [Setup]
    let world = setup::spawn_game();

    // [Create]
    world.execute('create', array![ACCOUNT, SEED, NAME, PLAYER_COUNT.into()]);

    // [Transfer]
    set_contract_address(starknet::contract_address_const::<1>());
    world.execute('transfer', array![ACCOUNT, 0, 0, 0]);
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(
    expected: (
        'Transfer: invalid owner', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED',
    )
)]
fn test_transfer_revert_invalid_owner() {
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
    world.execute('transfer', array![ACCOUNT, index.into(), 0, 0]);
}
