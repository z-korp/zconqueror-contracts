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
use zconqueror::tests::setup::{setup, setup::{Systems, Context, HOST, PLAYER}};

// Constants

const HOST_NAME: felt252 = 'HOST';
const PLAYER_NAME: felt252 = 'PLAYER';
const PRICE: u256 = 1_000_000_000_000_000_000;
const PLAYER_COUNT: u8 = 2;
const PLAYER_INDEX: u8 = 0;

#[test]
#[available_gas(1_000_000_000)]
fn test_attack() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    let game_id = systems.host.create(world, HOST_NAME, PRICE);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);
    set_contract_address(HOST());
    systems.host.start(world, game_id);

    // [Compute] Attacker tile
    let game: Game = store.game(game_id);
    let initial_player: Player = store.player(game, PLAYER_INDEX);
    let supply = initial_player.supply.into();
    let mut attacker: u8 = 3;
    let army = loop {
        let tile: Tile = store.tile(game, attacker.into());
        if tile.owner == PLAYER_INDEX.into() {
            break tile.army;
        }
        attacker += 1;
    };

    // [Supply]
    set_contract_address(initial_player.address);
    systems.play.supply(world, game_id, attacker, supply);

    // [Finish]
    systems.play.finish(world, game_id);

    // [Compute] Defender tile
    let mut neighbors = config::neighbors(attacker).expect('Attack: invalid tile id');
    let mut defender = loop {
        match neighbors.pop_front() {
            Option::Some(index) => {
                let tile: Tile = store.tile(game, *index);
                if tile.owner != PLAYER_INDEX.into() {
                    break tile.id;
                }
            },
            Option::None => { panic(array!['Attack: defender not found']); }
        };
    };

    // [Attack]
    let distpached: u32 = (army + supply - 1).into();
    systems.play.attack(world, game_id, attacker, defender, distpached);
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Attack: invalid player', 'ENTRYPOINT_FAILED',))]
fn test_attack_revert_invalid_player() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    let game_id = systems.host.create(world, HOST_NAME, PRICE);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);
    set_contract_address(HOST());
    systems.host.start(world, game_id);

    // [Compute] Tile army and player available supply
    let game: Game = store.game(game_id);
    let initial_player: Player = store.player(game, PLAYER_INDEX);
    let supply: u32 = initial_player.supply.into();
    let mut tile_index: u8 = 1;
    loop {
        let tile: Tile = store.tile(game, tile_index.into());
        if tile.owner == PLAYER_INDEX.into() {
            break;
        }
        tile_index += 1;
    };

    // [Supply]
    set_contract_address(initial_player.address);
    systems.play.supply(world, game_id, tile_index, supply);

    // [Finish]
    systems.play.finish(world, game_id);

    // [Attack]
    set_contract_address(starknet::contract_address_const::<1>());
    systems.play.attack(world, game_id, 0, 0, 0);
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Attack: invalid owner', 'ENTRYPOINT_FAILED',))]
fn test_attack_revert_invalid_owner() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    let game_id = systems.host.create(world, HOST_NAME, PRICE);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);
    set_contract_address(HOST());
    systems.host.start(world, game_id);

    // [Compute] Tile army and player available supply
    let game: Game = store.game(game_id);
    let initial_player: Player = store.player(game, PLAYER_INDEX);
    let supply: u32 = initial_player.supply.into();
    let mut tile_index: u8 = 1;
    loop {
        let tile: Tile = store.tile(game, tile_index);
        if tile.owner == PLAYER_INDEX.into() {
            break;
        }
        tile_index += 1;
    };

    // [Supply]
    set_contract_address(initial_player.address);
    systems.play.supply(world, game_id, tile_index, supply);

    // [Finish]
    systems.play.finish(world, game_id);

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

    // [Attack]
    systems.play.attack(world, game_id, index, 0, 0);
}
