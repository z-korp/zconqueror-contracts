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
const PLAYER_COUNT: u8 = 2;
const PLAYER_INDEX: u8 = 0;

#[test]
#[available_gas(1_000_000_000)]
fn test_transfer_valid() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    let game_id = systems.host.create(world, PLAYER_COUNT, HOST_NAME);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);
    set_contract_address(HOST());
    systems.host.start(world, game_id);

    // [Compute] Tile army and player available supply
    let game: Game = store.game(game_id);
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

    // [Finish]
    systems.play.finish(world, game_id);

    // [Compute] First 2 owned tiles
    let mut tiles: Array<Tile> = array![];
    let mut tile_index: u8 = 1;
    loop {
        if tile_index.into() > config::TILE_NUMBER || tiles.len() == 2 {
            break;
        };
        let tile: Tile = store.tile(game, tile_index);
        if tile.owner == PLAYER_INDEX.into() {
            tiles.append(tile);
        }
        tile_index += 1;
    };

    // [Transfer]
    let from = tiles.pop_front().unwrap();
    let to = tiles.pop_front().unwrap();
    let army = from.army - 1;
    systems.play.transfer(world, game_id, from.id, to.id, army);

    // [Assert] Source army
    let tile: Tile = store.tile(game, from.id);
    assert(tile.army == 1, 'Tile: wrong from army');

    // [Assert] Target army
    let tile: Tile = store.tile(game, to.id);
    assert(tile.army == to.army + army, 'Tile: wrong to army');
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Transfer: invalid player', 'ENTRYPOINT_FAILED',))]
fn test_transfer_revert_invalid_player() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    let game_id = systems.host.create(world, PLAYER_COUNT, HOST_NAME);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);
    set_contract_address(HOST());
    systems.host.start(world, game_id);

    // [Compute] Tile army and player available supply
    let game: Game = store.game(game_id);
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

    // [Finish]
    systems.play.finish(world, game_id);

    // [Transfer]
    set_contract_address(starknet::contract_address_const::<1>());
    systems.play.transfer(world, game_id, 0, 0, 0);
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Transfer: invalid owner', 'ENTRYPOINT_FAILED',))]
fn test_transfer_revert_invalid_owner() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    let game_id = systems.host.create(world, PLAYER_COUNT, HOST_NAME);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);
    set_contract_address(HOST());
    systems.host.start(world, game_id);

    // [Compute] Tile army and player available supply
    let game: Game = store.game(game_id);
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

    // [Finish]
    systems.play.finish(world, game_id);

    // [Compute] Invalid owned tile
    let game: Game = store.game(game_id);
    let mut index = 1;
    loop {
        let tile: Tile = store.tile(game, index);
        if tile.owner != PLAYER_INDEX.into() {
            break;
        }
        index += 1;
    };

    // [Transfer]
    systems.play.transfer(world, game_id, index, 0, 0);
}
