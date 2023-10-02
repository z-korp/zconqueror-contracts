// Core imports

use traits::{Into, TryInto};
use core::result::ResultTrait;
use array::{ArrayTrait, SpanTrait};
use option::OptionTrait;
use box::BoxTrait;
use clone::Clone;
use debug::PrintTrait;

// Starknet imports

use starknet::{ContractAddress, syscalls::deploy_syscall};
use starknet::class_hash::{ClassHash, Felt252TryIntoClassHash};
use starknet::testing::set_contract_address;

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
use dojo::test_utils::spawn_test_world;

// Internal imports

use zrisk::config;
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
fn test_attack() {
    // [Setup]
    let world = setup::spawn_game();

    // [Create]
    world.execute('create', array![ACCOUNT, SEED, NAME, PLAYER_COUNT.into()]);

    // [Compute] Attacker tile
    let game: Game = get!(world, ACCOUNT, (Game));
    let initial_player: Player = get!(world, (game.id, PLAYER_INDEX).into(), (Player));
    let supply = initial_player.supply.into();
    let mut attacker_index = 0;
    let army = loop {
        let tile: Tile = get!(world, (game.id, attacker_index).into(), (Tile));
        if tile.owner == PLAYER_INDEX {
            break tile.army;
        }
        attacker_index += 1;
    };

    // [Supply]
    world.execute('supply', array![ACCOUNT, attacker_index.into(), supply.into()]);

    // [Compute] Defender tile
    let mut neighbors = config::neighbors(attacker_index).expect('Attack: invalid tile id');
    let mut defender_index = loop {
        match neighbors.pop_front() {
            Option::Some(index) => {
                let tile: Tile = get!(world, (game.id, *index).into(), (Tile));
                if tile.owner != PLAYER_INDEX {
                    break tile.index;
                }
            },
            Option::None => {
                panic(array!['Attack: defender not found']);
            },
        };
    };

    // [Attack]
    let distpached: felt252 = (army + supply - 1).into();
    world
        .execute(
            'attack', array![ACCOUNT, attacker_index.into(), defender_index.into(), distpached]
        );
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(
    expected: (
        'Attack: invalid tile index', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED',
    )
)]
fn test_attack_invalid_source_index() {
    // [Setup]
    let world = setup::spawn_game();

    // [Attack]
    world.execute('attack', array![ACCOUNT, config::TILE_NUMBER.into(), 0, 0]);
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(
    expected: (
        'Attack: invalid tile index', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED',
    )
)]
fn test_attack_invalid_target_index() {
    // [Setup]
    let world = setup::spawn_game();

    // [Attack]
    world.execute('attack', array![ACCOUNT, 0, config::TILE_NUMBER.into(), 0]);
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(
    expected: (
        'Attack: invalid dispatched', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED',
    )
)]
fn test_attack_invalid_dispatched() {
    // [Setup]
    let world = setup::spawn_game();

    // [Attack]
    world.execute('attack', array![ACCOUNT, 0, 1, 0]);
}

#[test]
#[available_gas(1_000_000_000)]
#[should_panic(
    expected: (
        'Attack: invalid owner', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED',
    )
)]
fn test_attack_invalid_owner() {
    // [Setup]
    let world = setup::spawn_game();

    // [Create]
    world.execute('create', array![ACCOUNT, SEED, NAME, PLAYER_COUNT.into()]);

    // [Compute] Attacker tile
    let game: Game = get!(world, ACCOUNT, (Game));
    let initial_player: Player = get!(world, (game.id, PLAYER_INDEX).into(), (Player));
    let supply = initial_player.supply.into();
    let mut attacker_index = 0;
    let army = loop {
        let tile: Tile = get!(world, (game.id, attacker_index).into(), (Tile));
        if tile.owner == PLAYER_INDEX {
            break tile.army;
        }
        attacker_index += 1;
    };

    // [Supply]
    world.execute('supply', array![ACCOUNT, attacker_index.into(), supply.into()]);

    // [Compute] Defender tile
    let mut neighbors = config::neighbors(attacker_index).expect('Attack: invalid tile id');
    let mut defender_index = loop {
        match neighbors.pop_front() {
            Option::Some(index) => {
                let tile: Tile = get!(world, (game.id, *index).into(), (Tile));
                if tile.owner != PLAYER_INDEX {
                    break tile.index;
                }
            },
            Option::None => {
                panic(array!['Attack: defender not found']);
            },
        };
    };

    // [Attack]
    let distpached: felt252 = (army + supply - 1).into();
    world
        .execute(
            'attack', array![ACCOUNT, defender_index.into(), defender_index.into(), distpached]
        );
}
