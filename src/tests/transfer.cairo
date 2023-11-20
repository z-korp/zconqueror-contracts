// Core imports

use debug::PrintTrait;

// Starknet imports

use starknet::testing::set_contract_address;

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports

use zconqueror::config;
use zconqueror::datastore::{DataStore, DataStoreTrait};
use zconqueror::components::game::{Game, GameTrait, Turn};
use zconqueror::components::player::Player;
use zconqueror::components::tile::Tile;
use zconqueror::systems::player::IActionsDispatcherTrait;
use zconqueror::tests::setup::{setup, setup::Systems};

// Constants

const ACCOUNT: felt252 = 'ACCOUNT';
const SEED: felt252 = 'BANG';
const NAME: felt252 = 'NAME';
const PLAYER_COUNT: u8 = 2;
const PLAYER_INDEX: u8 = 0;

#[test]
#[available_gas(1_000_000_000)]
fn test_transfer_valid() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    systems.player_actions.create(world, ACCOUNT, SEED, NAME, PLAYER_COUNT);

    // [Compute] Tile army and player available supply
    let game: Game = datastore.game(ACCOUNT);
    let player: Player = datastore.player(game, PLAYER_INDEX);
    let supply: u32 = player.supply.into();
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

    // [Finish]
    systems.player_actions.finish(world, ACCOUNT);

    // [Compute] First 2 owned tiles
    let mut tiles: Array<Tile> = array![];
    let mut tile_index: u8 = 1;
    loop {
        if tile_index.into() > config::TILE_NUMBER || tiles.len() == 2 {
            break;
        };
        let tile: Tile = datastore.tile(game, tile_index);
        if tile.owner == PLAYER_INDEX.into() {
            tiles.append(tile);
        }
        tile_index += 1;
    };

    // [Transfer]
    let source = tiles.pop_front().unwrap();
    let target = tiles.pop_front().unwrap();
    let army = source.army - 1;
    systems.player_actions.transfer(world, ACCOUNT, source.index, target.index, army);

    // [Assert] Source army
    let tile: Tile = datastore.tile(game, source.index);
    assert(tile.army == 1, 'Tile: wrong source army');

    // [Assert] Target army
    let tile: Tile = datastore.tile(game, target.index);
    assert(tile.army == target.army + army, 'Tile: wrong target army');
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Transfer: invalid player', 'ENTRYPOINT_FAILED',))]
fn test_transfer_revert_invalid_player() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    systems.player_actions.create(world, ACCOUNT, SEED, NAME, PLAYER_COUNT);

    // [Compute] Tile army and player available supply
    let game: Game = datastore.game(ACCOUNT);
    let player: Player = datastore.player(game, PLAYER_INDEX);
    let supply: u32 = player.supply.into();
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

    // [Finish]
    systems.player_actions.finish(world, ACCOUNT);

    // [Transfer]
    set_contract_address(starknet::contract_address_const::<1>());
    systems.player_actions.transfer(world, ACCOUNT, 0, 0, 0);
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Transfer: invalid owner', 'ENTRYPOINT_FAILED',))]
fn test_transfer_revert_invalid_owner() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    systems.player_actions.create(world, ACCOUNT, SEED, NAME, PLAYER_COUNT);

    // [Compute] Tile army and player available supply
    let game: Game = datastore.game(ACCOUNT);
    let player: Player = datastore.player(game, PLAYER_INDEX);
    let supply: u32 = player.supply.into();
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

    // [Transfer]
    systems.player_actions.transfer(world, ACCOUNT, index, 0, 0);
}
