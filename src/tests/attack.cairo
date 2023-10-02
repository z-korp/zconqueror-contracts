// Core imports

use debug::PrintTrait;

// Starknet imports

use starknet::testing::set_contract_address;

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

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
    let mut attacker = 1;
    let army = loop {
        let tile: Tile = get!(world, (game.id, attacker).into(), (Tile));
        if tile.owner == PLAYER_INDEX {
            break tile.army;
        }
        attacker += 1;
    };

    // [Supply]
    world.execute('supply', array![ACCOUNT, attacker.into(), supply.into()]);

    // [Finish]
    world.execute('finish', array![ACCOUNT]);

    // [Compute] Defender tile
    let mut neighbors = config::neighbors(attacker).expect('Attack: invalid tile id');
    let mut defender = loop {
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
    world.execute('attack', array![ACCOUNT, attacker.into(), defender.into(), distpached]);
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(
    expected: (
        'Attack: invalid player', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED',
    )
)]
fn test_attack_revert_invalid_player() {
    // [Setup]
    let world = setup::spawn_game();

    // [Create]
    world.execute('create', array![ACCOUNT, SEED, NAME, PLAYER_COUNT.into()]);

    // [Compute] Tile army and player available supply
    let game: Game = get!(world, ACCOUNT, (Game));
    let initial_player: Player = get!(world, (game.id, PLAYER_INDEX).into(), (Player));
    let supply: felt252 = initial_player.supply.into();
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

    // [Attack]
    set_contract_address(starknet::contract_address_const::<1>());
    world.execute('attack', array![ACCOUNT, 0, 0, 0]);
}


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(
    expected: (
        'Attack: invalid owner', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED',
    )
)]
fn test_attack_revert_invalid_owner() {
    // [Setup]
    let world = setup::spawn_game();

    // [Create]
    world.execute('create', array![ACCOUNT, SEED, NAME, PLAYER_COUNT.into()]);

    // [Compute] Tile army and player available supply
    let game: Game = get!(world, ACCOUNT, (Game));
    let initial_player: Player = get!(world, (game.id, PLAYER_INDEX).into(), (Player));
    let supply: felt252 = initial_player.supply.into();
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

    // [Attack]
    world.execute('attack', array![ACCOUNT, index.into(), 0, 0]);
}
