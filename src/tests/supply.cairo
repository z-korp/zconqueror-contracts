// Core imports

use debug::PrintTrait;

// Starknet imports

use starknet::testing::set_contract_address;

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports

use zconqueror::config;
use zconqueror::store::{Store, StoreTrait};
use zconqueror::models::game::{Game, GameTrait};
use zconqueror::models::player::Player;
use zconqueror::models::tile::Tile;
use zconqueror::systems::host::IHostDispatcherTrait;
use zconqueror::systems::play::IPlayDispatcherTrait;
use zconqueror::tests::setup::{setup, setup::Systems};

// Constants

const NAME: felt252 = 'NAME';
const PLAYER_COUNT: u8 = 2;
const PLAYER_INDEX: u8 = 0;

#[test]
#[available_gas(1_000_000_000)]
fn test_supply() {
    let (world, systems) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    let game_id = systems.host.create(world, PLAYER_COUNT, NAME);
    systems.host.start(world, game_id);

    // [Compute] Tile army and player available supply
    let game: Game = store.game(game_id);
    let initial_player: Player = store.player(game, PLAYER_INDEX);
    let supply = initial_player.supply.into();
    let mut tile_index: u8 = 1;
    let army = loop {
        let tile: Tile = store.tile(game, tile_index.into());
        if tile.owner == PLAYER_INDEX.into() {
            break tile.army;
        }
        tile_index += 1;
    };

    // [Supply]
    systems.play.supply(world, game_id, tile_index, supply);

    // [Assert] Player supply
    let player: Player = store.player(game, PLAYER_INDEX);
    assert(player.supply == 0, 'Player: wrong supply');

    // [Assert] Tile supplied
    let tile: Tile = store.tile(game, tile_index.into());
    assert(tile.army == army + supply, 'Tile: wrong army');
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Supply: invalid player', 'ENTRYPOINT_FAILED',))]
fn test_supply_revert_invalid_player() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    let game_id = systems.host.create(world, PLAYER_COUNT, NAME);
    systems.host.start(world, game_id);

    // [Supply]
    set_contract_address(starknet::contract_address_const::<1>());
    systems.play.supply(world, game_id, 0, 0);
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Supply: invalid owner', 'ENTRYPOINT_FAILED',))]
fn test_supply_revert_invalid_owner() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    let game_id = systems.host.create(world, PLAYER_COUNT, NAME);
    systems.host.start(world, game_id);

    // [Compute] Invalid owned tile
    let game: Game = store.game(game_id);
    let mut index: u8 = 1;
    loop {
        let tile: Tile = store.tile(game, index);
        if tile.owner != PLAYER_INDEX.into() {
            break;
        }
        index += 1;
    };

    // [Transfer]
    systems.play.supply(world, game_id, index, 0);
}
