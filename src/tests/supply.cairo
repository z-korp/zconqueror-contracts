// Core imports

use debug::PrintTrait;

// Starknet imports

use starknet::testing::set_contract_address;

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports

use zconqueror::config;
use zconqueror::datastore::{DataStore, DataStoreTrait};
use zconqueror::components::game::{Game, GameTrait};
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
fn test_supply() {
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    systems.player_actions.create(world, ACCOUNT, SEED, NAME, PLAYER_COUNT);

    // [Compute] Tile army and player available supply
    let game: Game = datastore.game(ACCOUNT);
    let initial_player: Player = datastore.player(game, PLAYER_INDEX);
    let supply = initial_player.supply.into();
    let mut tile_index: u8 = 1;
    let army = loop {
        let tile: Tile = datastore.tile(game, tile_index.into());
        if tile.owner == PLAYER_INDEX.into() {
            break tile.army;
        }
        tile_index += 1;
    };

    // [Supply]
    systems.player_actions.supply(world, ACCOUNT, tile_index, supply);

    // [Assert] Player supply
    let player: Player = datastore.player(game, PLAYER_INDEX);
    assert(player.supply == 0, 'Player: wrong supply');

    // [Assert] Tile supplied
    let tile: Tile = datastore.tile(game, tile_index.into());
    assert(tile.army == army + supply, 'Tile: wrong army');
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Supply: invalid player', 'ENTRYPOINT_FAILED',))]
fn test_supply_revert_invalid_player() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    systems.player_actions.create(world, ACCOUNT, SEED, NAME, PLAYER_COUNT);

    // [Supply]
    set_contract_address(starknet::contract_address_const::<1>());
    systems.player_actions.supply(world, ACCOUNT, 0, 0);
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Supply: invalid owner', 'ENTRYPOINT_FAILED',))]
fn test_supply_revert_invalid_owner() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut datastore = DataStoreTrait::new(world);

    // [Create]
    systems.player_actions.create(world, ACCOUNT, SEED, NAME, PLAYER_COUNT);

    // [Compute] Invalid owned tile
    let game: Game = datastore.game(ACCOUNT);
    let mut index: u8 = 1;
    loop {
        let tile: Tile = datastore.tile(game, index);
        if tile.owner != PLAYER_INDEX.into() {
            break;
        }
        index += 1;
    };

    // [Transfer]
    systems.player_actions.supply(world, ACCOUNT, index, 0);
}
